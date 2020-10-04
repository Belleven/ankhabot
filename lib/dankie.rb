require_relative 'versión'
require_relative 'handlers'
require_relative 'logger'
require_relative 'telegram'
require_relative 'images'
require_relative 'last_fm_parser'
require_relative 'botoneras'
require_relative 'configuración'
require_relative 'estadísticas'
require_relative 'excepciones'
require_relative 'dankie_auxiliares'
require 'redis'
require 'tzinfo'
require 'set'
require 'securerandom'
require 'ruby_reddit_api'
require 'cgi'

class Dankie
    attr_reader :tg, :logger, :redis, :reddit, :user

    TROESMAS = File.readlines('resources/troesmas.txt', encoding: 'UTF-8').map(&:chomp)
    TROESMAS.freeze
    REKT = File.readlines('resources/rekt.txt', encoding: 'UTF-8').map(&:chomp).freeze
    CALLEFUEGOS = File.readlines('resources/callefuegos.txt').map(&:chomp).freeze
    DEUS_VULT = File.readlines('resources/deus.txt').map(&:chomp).freeze
    # rubocop:disable Layout/MultilineArrayBraceLayout
    DEVS = Set.new([240_524_686, # Luke
                    98_631_116,  # M
                    812_107_125, # Santi
                    267_832_653, # Galerazo
                    257_266_743, # Fran
                    340_357_825  # Chiro
    ]).freeze
    # rubocop:enable Layout/MultilineArrayBraceLayout

    # Recibe un Hash con los datos de config.yml
    def initialize(args)
        @canal = args[:canal_logging]

        # Tanto tg como dankielogger usan un cliente para mandar mensajes
        # Y además tg usa un logger
        @logger = DankieLogger.new(args[:archivo_logging], @canal)
        @tg = TelegramAPI.new args[:tg_token], @logger
        @logger.inicializar_cliente @tg.client

        # Creo dos instancias de Redis, una base de datos general y una de estadísticas
        @redis = Redis.new(
            port: args[:redis_port],
            host: args[:redis_host],
            password: args[:redis_pass],
            db: 0
        )
        Estadísticas::Base.redis = Redis.new(
            port: args[:redis_port],
            host: args[:redis_host],
            password: args[:redis_pass],
            db: 1
        )

        @img = ImageSearcher.new args[:google_image_key], args[:google_image_cx],
                                 args[:google_image_gl], @logger

        @user = Telegram::Bot::Types::User.new @tg.get_me['result']

        @lastfm = LastFM::Api.new args[:last_fm_api]

        @tz = TZInfo::Timezone.get args[:timezone]

        @reddit_api = Reddit::Api.new
    end

    # Creo que esto es un dispatch si entendí bien
    def dispatch(msj)
        # Handlers generales, no los de comando si no los de mensajes/eventos de chat
        self.class.handlers.each do |handler|
            handler.ejecutar(self, msj) if handler.verificar(self, msj)
        end

        # Handlers de comando
        return unless msj.is_a? Telegram::Bot::Types::Message

        self.class.comandos[get_command(msj)]&.ejecutar(self, msj)
    end

    def run
        # Ciclo principal
        @tg.client.listen do |msj|
            # Registra cuanto tiempo tarda en ejecutar el loop del bot
            Estadísticas::Temporizador.time('tiempo_procesado_loop', intervalo: 600) do
                loop_principal(msj)
            end
        rescue StandardError => e
            manejar_excepción_asesina(e)
            retry
        end
    end

    def loop_principal(msj)
        # Si se cerró una encuesta, no hago nada más que loggear
        if msj.is_a?(Telegram::Bot::Types::Poll)
            información = 'Se acaba de cerrar esta encuesta:'
            agregar_encuesta(información, msj, 1, false)
            @logger.info información
            return
        end

        # Chequeo que msj sea un mensaje válido, y que quien lo manda no
        # esté bloqueado por el bot, o restringido del bot en el chat
        return unless msj&.from&.id
        return if @redis.sismember('lista_negra:global', msj.from.id.to_s)
        return if msj.is_a?(Telegram::Bot::Types::Message) &&
                  @redis.sismember("lista_negra:#{msj.chat.id}", msj.from.id.to_s)

        # Le paso el mensaje a los handlers correspondientes
        dispatch(msj)
    rescue StandardError => e
        manejar_excepción_asesina(e, msj)
    end

    def manejar_excepción_asesina(excepción, msj = nil)
        return if @tg.capturar(excepción)

        unless msj.nil? || msj.class == Telegram::Bot::Types::CallbackQuery
            @logger.loggear_hora_excepción(msj, @tz.utc_offset, @tz.now)
        end

        texto, backtrace = @logger.excepcion_texto(excepción)
        @logger.fatal texto, al_canal: true, backtrace: backtrace
    rescue StandardError => e
        @logger.fatal "EXCEPCIÓN: #{e}\nLEYENDO LA EXCEPCIÓN: #{excepción}\n\n"\
                      "#{@logger.excepcion_texto(e).last}", al_canal: true
    end

    def self.add_handler(handler)
        @comandos ||= {}
        @handlers ||= []

        if handler.is_a? Handler::Comando
            @comandos[handler.cmd] = handler
        else
            @handlers << handler
        end
    end

    def self.handlers
        @handlers ||= []
    end

    def self.comandos
        @comandos ||= {}
    end

    # Permite iterar sobre los comandos del bot, y sus descripciones
    def self.commands
        @comandos.each_value do |comando|
            yield comando.cmd, comando.descripción if comando.descripción
        end
    end

    def get_command(msj)
        cmd = _parse_command(msj)
        cmd[:command]
    end

    # Este método analiza parámetros en el mensaje. se podría hacer una combinación
    # tomando parámetros de acá y usar un mensaje respondido como el resto del
    # argumento, pero eso no se hace acá porque podría ser peligroso en algunos
    # comandos.
    def get_command_params(msj)
        cmd = _parse_command(msj)
        cmd[:params]
    end

    private

    # Analiza un texto y se fija si es un comando válido, devuelve el comando
    # y el resto del texto
    def _parse_command(msj)
        respuesta = { command: nil, params: nil }

        return respuesta unless (texto = msj.text || msj.caption)
        return respuesta if texto.size <= 1

        # "/cmd params" o "/cmd@bot params"
        return comando_barra(texto) if texto.start_with? '/'

        # "!cmd params" o ">cmd params"
        return comando_símbolo(texto) if ['!', '>', '$', '.'].include? texto[0]

        parsear_otros_comandos(texto, msj, respuesta)
    end

    def parsear_otros_comandos(texto, msj, respuesta)
        # ["usuario", "comando", "params"]
        arr = texto.split(' ', 3)
        arr.first.downcase!

        if (arr.size > 1) && arr.first.casecmp(@user.username[0..-4]).zero?
            comando_alias arr
        # Responde al bot
        elsif msj.reply_to_message&.from&.id == @user.id
            comando_respuesta_bot texto
        else
            respuesta
        end
    end

    def comando_barra(texto)
        comando, params = texto.split ' ', 2
        comando.downcase!
        comando.gsub!(%r{^/([_a-z]+)(@#{@user.username.downcase})?}, '\\1')
        devolver_dicc_comando_params(comando, params)
    end

    def comando_símbolo(texto)
        comando, params = texto.split ' ', 2
        comando = comando[1..]
        comando.downcase!
        devolver_dicc_comando_params(comando, params)
    end

    def comando_alias(arr)
        comando = arr[1].downcase.to_sym
        params = arr[2]
        devolver_dicc_comando_params(comando, params)
    end

    def comando_respuesta_bot(texto)
        comando, params = texto.split ' ', 2
        comando.downcase!
        devolver_dicc_comando_params(comando, params)
    end

    def devolver_dicc_comando_params(comando, params)
        { command: comando&.to_sym, params: params }
    end
end
