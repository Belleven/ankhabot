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
    # El único lugar donde se usa el logger por fuera del bot es en handlers, las
    # otras cosas no vi que se usaran
    attr_reader :logger

    TROESMAS = File.readlines('resources/troesmas.txt', encoding: 'UTF-8')
                   .map(&:chomp).freeze
    REKT = File.readlines('resources/rekt.txt', encoding: 'UTF-8').map(&:chomp).freeze
    CALLEFUEGOS = File.readlines('resources/callefuegos.txt').map(&:chomp).freeze
    DEUS_VULT = File.readlines('resources/deus.txt').map(&:chomp).freeze
    CHANGELOG = './CHANGELOG'.freeze
    DEVS = Set.new(
        [
            240_524_686, # Luke
            812_107_125, # Santi
            267_832_653, # Galerazo
            257_266_743, # Fran
            340_357_825  # Chiro
        ]
    ).freeze

    class << self
        attr_reader :comandos, :inlinequery, :callback_queries, :handlers_generales
    end

    def self.add_handler(handler)
        case handler

        when Handler::Comando
            @comandos ||= {}
            @comandos[handler.cmd] = handler

        when Handler::Mensaje, Handler::EventoDeChat
            @handlers_generales ||= []
            @handlers_generales << handler

        when Handler::CallbackQuery
            @callback_queries ||= {}
            @callback_queries[handler.clave] = handler

        when Handler::InlineQuery
            @inlinequery ||= []
            @inlinequery << handler

        else
            printf @archivo_logging, "\nHandler inválido: #{handler}\n"
        end
    end

    # Recibe un Hash con los datos de config.yml
    def initialize(args)
        @canal = args[:canal_logging]
        @archivo_logging = args[:archivo_logging] || $stderr
        # Tanto tg como dankielogger usan un cliente para mandar mensajes
        # Y además tg usa un logger
        @logger = DankieLogger.new(@archivo_logging, @canal)
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

        @user = Telegram::Bot::Types::User.new @tg.get_me['result']

        inicializar_apis_externas args

        Telegram::Bot::Types::Base.attr_accessor :datos_crudos
        return unless /\A--(no|s(in|altear))-updates\z/i.match? ARGV.first

        @redis.set('datos_bot:id_actualización_inicial', -1)
    end

    def run
        @logger.info 'Bot tomando updates...'
        procesando = false
        apagar_programa = false

        # La idea de esto es que se muera el bot recién después de procesar
        # el bloque de updates, en un futuro lo que quiero hacer (cuando esté
        # todo en paralelo con corrutinas o lo que sea) es que se muera el bot
        # sí y solo sí ningún comando se esté ejecutando
        Signal.trap('INT') do
            apagar_bot unless procesando
            printf @archivo_logging,
                   "\nEsperando a procesar últimas updates para apagar el bot...\n"
            apagar_programa = true
        end

        # En un futuro tirar esto en un proceso a parte xdd
        correr_antes_de_actualizaciones

        loop do
            actualizaciones = @tg.get_updates(
                # Si la clave no existe, el .to_i convierte el nil en 0
                offset: @redis.get('datos_bot:id_actualización_inicial').to_i,
                timeout: 7,
                url: 'https://api.telegram.org'
            )

            next unless actualizaciones

            # El tan odiadio GIL de ruby nos asegura que no va a haber condiciones
            # de carrera entre estas tres líneas y el código dentro del Signal.trap
            procesando = true
            procesar_actualizaciones(actualizaciones)
            procesando = false

            return apagar_bot if apagar_programa
        end
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError,
           HTTPClient::ReceiveTimeoutError, Net::OpenTimeout => e
        @logger.fatal "Error de conección, no hay internés: #{e.class}", al_canal: false
        return apagar_bot if apagar_programa

        retry
    rescue StandardError => e
        manejar_excepción_asesina(e)
        return apagar_bot if apagar_programa

        retry
    end

    def obtener_comando(msj)
        cmd = _parsear_comando(msj)
        cmd[:comando]
    end

    # Este método analiza parámetros en el mensaje. se podría hacer una combinación
    # tomando parámetros de acá y usar un mensaje respondido como el resto del
    # argumento, pero eso no se hace acá porque podría ser peligroso en algunos
    # comandos.
    def obtener_params_comando(msj)
        cmd = _parsear_comando(msj)
        cmd[:params]
    end

    private

    def correr_antes_de_actualizaciones
        # Inializo la clase de configuraciones
        Configuración.redis ||= @redis

        # Compruebo si la version del Bot concuerda con la del changelog
        @logger.info 'Comprobando versión...'
        comprobar_version
    end

    def comprobar_version
        archivo = File.open(CHANGELOG, 'r') { |f| archivo = f.read }
        versión_changelog = archivo.scan(/\AVersión (\d(\.\d)*)\s*\n/).first.first

        if VERSIÓN != versión_changelog
            abort('La versión del bot y del changelog difieren')
        end

        ultima_version_informada = version_redis
        # Si es nil, va a ser != a VERSION que es un string
        if ultima_version_informada == VERSIÓN
            @logger.info '¡Versión actualizada!'
            return
        end

        # Si hay un tablero
        if (id_tablero = @redis.get('versión:id_tablero_anuncio'))
            if @redis.get('versión:versión_tablero_anuncio') == VERSIÓN
                @logger.info 'Tablero de anuncio nueva versión ya enviado'
                return
            end

            begin
                @tg.delete_message(chat_id: @canal, message_id: id_tablero.to_i)
            rescue Telegram::Bot::Exceptions::ResponseError => e
                @logger.info(
                    "No pude borrar el tablero de anuncio anterior:\n#{e.message}"
                )
            end
        end

        @logger.info 'Se ha detectado un cambio de versión para informar'
        confirmar_anuncio_changelog(VERSIÓN, ultima_version_informada)
    end

    def actualizar_version_redis
        @redis.set('versión', VERSIÓN)
    end

    def version_redis
        @redis.get('versión')
    end

    def inicializar_apis_externas(args)
        @img = ImageSearcher.new args[:google_image_key], args[:google_image_cx],
                                 args[:google_image_gl], @logger

        @lastfm = LastFM::Api.new args[:last_fm_api]
        @tz = TZInfo::Timezone.get args[:timezone]
        @reddit_api = Reddit::Api.new
    end

    # En un futuro este método puede lanar una corrutina por update
    def procesar_actualizaciones(actualizaciones)
        actualizaciones['result'].each do |actualización|
            Estadísticas::Temporizador.time('tiempo_loop', intervalo: 600) do
                act = Telegram::Bot::Types::Update.new(actualización)
                @logger.info "Procesando update #{act.update_id}"
                mensaje = act.current_message

                mensaje.datos_crudos = actualización
                loop_principal(mensaje)
            end
        end

        próxima_update = actualizaciones['result'].last['update_id'].next
        @redis.set 'datos_bot:id_actualización_inicial', próxima_update
    end

    # En el futuro concurrente de la dankie, acá vamos a estar en paralelo
    # analizando una update, además se puede agregar otro hilo o algo así que
    # las analice de forma sincrónica
    def loop_principal(msj)
        return if actualización_de_usuario_bloqueado? msj

        despachar msj
    # Acá está bueno handlear excepciones de updates porque si rompe más arriba
    # se puede romper el bucle donde se analizan las otras updates y como pueden
    # venir de hasta 100 no queremos que pase eso
    rescue StandardError => e
        manejar_excepción_asesina(e, msj, msj.datos_crudos)
    end

    # Creo que esto es un dispatch si entendí bien
    def despachar(msj)
        case msj

        when Telegram::Bot::Types::Message
            # Handlers generales, no los de comandos, si no
            # los de mensajes/eventos de chat
            Dankie.handlers_generales.each do |handler|
                next unless handler.verificar(self, msj)

                handler.ejecutar self, msj
            end

            datos = _parsear_comando(msj)
            Dankie.comandos[datos[:comando]]&.ejecutar self, msj, datos

        when Telegram::Bot::Types::CallbackQuery
            clave = msj.data.split(':').first
            Dankie.callback_queries[clave].ejecutar self, msj

        when Telegram::Bot::Types::InlineQuery
            Dankie.inlinequery.each do |handler|
                handler.ejecutar self, msj
            end
        else
            actualizaciones_poco_usuales msj
        end
    end

    def actualizaciones_poco_usuales(msj)
        case msj
        when Telegram::Bot::Types::ChosenInlineResult
            @logger.info 'Llegó el resultado elegido inline, '\
                         "id: #{msj.result_id}", al_canal: true

        # Si se cerró una encuesta, no hago nada más que loggear
        when Telegram::Bot::Types::Poll
            @logger.info "Se acaba de cerrar una encuesta con id: #{msj.id}"

        when Telegram::Bot::Types::PollAnswer
            @logger.info "Recibí una PollAnswer como update: #{msj}",
                         al_canal: true

        when Telegram::Bot::Types::ShippingQuery
            @logger.info "Recibí una ShippingQuery con id: #{msj.id}",
                         al_canal: true

        when Telegram::Bot::Types::PreCheckoutQuery
            @logger.info "Recibí una PreCheckoutQuery con id: #{msj.id}",
                         al_canal: true

        else
            @logger.error "Update desconocida: #{msj.class}\n"\
                          "#{msj.inspect}", al_canal: true
        end
    end

    def manejar_excepción_asesina(excepción, msj = nil, datos_crudos = nil)
        return if @tg.capturar(excepción)

        if msj.respond_to?(:date)
            @logger.loggear_hora_excepción(msj, @tz.utc_offset, @tz.now)
        end

        if datos_crudos
            @logger.info "Update que rompió:\n\n#{debug_bonita(datos_crudos)}",
                         al_canal: true
        end

        texto, backtrace = @logger.excepcion_texto(excepción)
        @logger.fatal texto, al_canal: true, backtrace: backtrace
    rescue StandardError => e
        begin
            @logger.fatal "EXCEPCIÓN: #{e}\n\n#{@logger.excepcion_texto(e).last}\n\n"\
                          "LEYENDO LA EXCEPCIÓN: #{excepción}\n\n"\
                          "#{@logger.excepcion_texto(excepción).last}",
                          al_canal: true
        rescue StandardError => e
            printf @archivo_logging,
                   "\nFATAL: Múltiples excepciones\n#{excepción}\n\n#{e}\n\n#{e}\n"
        end
    end

    # Por ahora esto es para loggear que se va a apagar, pero en un futuro capaz
    # si hay que hacer más cosas se puede agregar acá
    def apagar_bot
        printf @archivo_logging, "\nApagando bot...\n"
        exit
    end

    # Veo que la update tenga usuario, de ser así veo si ese usuario está bloqueado.
    # Si no está bloqueado y la update trae chat, veo si el usuario está bloqueado en
    # ese chat.
    def actualización_de_usuario_bloqueado?(msj)
        (msj.respond_to?(:from) && msj.from.respond_to?(:id) && !msj.from.id.nil?) &&
            (@redis.sismember('lista_negra:global', msj.from.id) ||
            (msj.respond_to?(:chat) && msj.chat.respond_to?(:id) && !msj.chat.id.nil? &&
             @redis.sismember("lista_negra:#{msj.chat.id}", msj.from.id)))
    end

    # Analiza un texto y se fija si es un comando válido, devuelve el comando
    # y el resto del texto
    def _parsear_comando(msj)
        respuesta = { comando: nil, params: nil }

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
        { comando: comando&.to_sym, params: params }
    end
end
