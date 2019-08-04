require_relative 'version.rb'
require_relative 'handlers.rb'
require_relative 'telegram.rb'
require_relative 'images.rb'
require_relative 'last_fm_parser.rb'
require_relative 'semáforo.rb'
require 'redis'
require 'tzinfo'
require 'set'

class Dankie
    attr_reader :tg, :logger, :redis, :reddit, :user
    TROESMAS = File.readlines('resources/troesmas.txt', encoding: 'UTF-8').map(&:chomp).freeze
    REKT = File.readlines('resources/rekt.txt', encoding: 'UTF-8').map(&:chomp).freeze
    CALLEFUEGOS = File.readlines('resources/callefuegos.txt').map(&:chomp).freeze
    DEUS_VULT = File.readlines('resources/deus.txt').map(&:chomp).freeze
    DEVS = Set.new([240_524_686, # Luke
                    98_631_116,  # M
                    263_078_683, # Santi
                    267_832_653, # Galerazo
                    196_535_916, # Ale
                    298_088_760, # Mel
                    36_557_595   # Bruno
    ]).freeze

    def self.add_handler(handler)
        @handlers ||= []
        @handlers << handler
    end

    def self.handlers
        @handlers ||= []
    end

    # Creo que esto es un dispatch si entendí bien
    def dispatch(msj)
        self.class.handlers.each do |handler|
            handler.check_message(self, msj)
        end
    end

    # Recibe un Hash con los datos de config.yml
    def initialize(args)
        @logger = Logger.new $stderr
        @canal_logging = args[:canal_logging]
        @tg = TelegramAPI.new args[:tg_token], @logger
        @redis = Redis.new port: args[:redis_port], host: args[:redis_host], password: args[:redis_pass]
        @img = ImageSearcher.new args[:google_image_key], args[:google_image_cx]
        @user = Telegram::Bot::Types::User.new @tg.get_me['result']
        @lastFM = LastFMParser.new args[:last_fm_api]
        @tz = TZInfo::Timezone.get args[:timezone]
    end

    def run
        @tg.client.listen do |msj|
            next unless msj&.from&.id
            next if @redis.sismember('blacklist:global', msj.from.id.to_s)
            next if msj.is_a?(Telegram::Bot::Types::Message) &&
                    @redis.sismember("blacklist:#{msj.chat.id}", msj.from.id.to_s)

            dispatch(msj)

        rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
            begin
                texto, backtrace = excepcion_texto(e)
                log Logger::ERROR, texto, al_canal: true, backtrace: backtrace
            rescue StandardError => e
                log Logger::FATAL, 'EXCEPCIÓN LEYENDO LA EXCEPCIÓN', al_canal: true
            end
            retry

        rescue StandardError => e

            begin
                texto, backtrace = excepcion_texto(e)
                log Logger::FATAL, texto, al_canal: true, backtrace: backtrace
            rescue StandardError => e
                log Logger::FATAL, 'EXCEPCIÓN LEYENDO LA EXCEPCIÓN', al_canal: true
            end

            # Sacar este raise cuando el bot deje de ser testeadísimo
            # lo puse porque luke dice que es pesado cuando se pone a mandar
            # errores en el grupete.
            raise
        end
    end

    # Permite iterar sobre los comandos del bot, y sus descripciones
    def self.commands
        @handlers.each do |handler|
            next unless handler.is_a? Handler::Comando

            yield handler.cmd, handler.description if handler.description
        end
    end

    # El to_s es al pedo, si lo que le pasamos no es un string entonces
    # tiene que saltar el error para que veamos bien que carajo le estamos pasando
    # Dejo el diccionario como variable para no tener que crearlo cada vez que se hace
    # un parseo. Hecho así solo recorre una vez el string en vez de 3.
    $html_dicc = { '&' => '&amp;', '<' => '&lt;', '>' => '&gt;' }
    def html_parser(texto)
        texto.gsub(/&|<|>/, $html_dicc)
    end

    def excepcion_texto(excepcion)
        texto_excepcion = excepcion.to_s
        texto = !(texto_excepcion.nil? || texto_excepcion.empty?) ? '(' + excepcion.class.to_s + ') ' + texto_excepcion : 'EXCEPCIÓN SIN NOMBRE'

        if excepcion.backtrace.nil?
            return texto, nil
        else
            # La regex turbina esa es para no doxxearnos a los que usamos linux
            # / es para "/" => /home/ es para "/home/"
            # [^/]+ es para que detecte todos los caracteres que no sean "/" => /home/user/dankie/... queda
            # como /dankie/...
            return texto, excepcion.backtrace.join("\n").gsub(%r{/home/[^/]+}, '~')
        end
    end

    def log(nivel, texto, al_canal: false, backtrace: nil)
        texto = 'LOG SIN NOMBRE' if texto.nil? || texto.empty?

        backtrace.nil? ? @logger.log(nivel, texto) : @logger.log(nivel, texto + "\n" + backtrace)

        return unless al_canal

        unless backtrace.nil?

            lineas = '<pre>' + ('-' * 30) + "</pre>\n"

            texto = html_parser(texto)
            texto << "\n" + lineas + lineas + "Rastreo de la excepción:\n" + lineas
            texto << "<pre>#{html_parser(backtrace)}</pre>"
        end

        nivel = case nivel
                when Logger::DEBUG
                    'DEBUG'
                when Logger::INFO
                    'INFO'
                when Logger::WARN
                    'WARN'
                when Logger::ERROR
                    'ERROR'
                when Logger::FATAL
                    'FATAL'
                when Logger::UNKNOWN
                    'UNKNOWN'
                end

        horario = Time.now.strftime('%FT%T.%6N')
        lineas = '<pre>' + '-' * (8 + horario.length + nivel.length) + "</pre>\n"

        enviar = "<pre>[#{horario}] -- #{nivel} :</pre>\n" + lineas + texto
        @tg.send_message(chat_id: @canal_logging, text: enviar,
                         parse_mode: :html, disable_web_page_preview: true)
    rescue StandardError => e
        begin
            lineas = ('-' * 30) + "\n"
            texto_excepcion = lineas + "\nMientras se manejaba una excepción surgió otra:\n"

            excepcion = e.to_s
            texto_excepcion << if !excepcion.nil? && !excepcion.empty?
                                   html_parser(e.to_s)
                               else
                                   'ERROR SIN NOMBRE'
                            end

            texto_excepcion << "\n" + lineas + lineas + e.backtrace.join("\n") + "\n" + lineas + lineas + "\n"
            @logger.log(Logger::FATAL, texto_excepcion)
        rescue StandardError => e
            puts "\nFATAL, multiples excepciones.\n"
        end
    end

    def get_command(msj)
        cmd = _parse_command(msj)
        cmd[:command]
    end

    def get_command_params(msj)
        cmd = _parse_command(msj)
        cmd[:params]
    end

    private

    # Analiza un texto y se fija si es un comando válido, devuelve el comando
    # y el resto del texto
    def _parse_command(msj)
        unless (text = msj.text || msj.caption)
            return { command: nil, params: nil }
        end

        command = nil
        params = nil

        if text.start_with? '/' # "/cmd params" o "/cmd@bot params"
            command, params = text.split ' ', 2
            command.downcase!
            command.gsub!(%r{^/([a-z]+)(@#{@user.username.downcase})?}, '\\1')

        elsif ['!', '>'].include? text[0] # "!cmd params" o ">cmd params"
            command, params = text[1..-1].split ' ', 2
            command.downcase!
        else
            arr = text.split(' ', 3) # ["user", "comando", "params"]
            if arr.first.casecmp(@user.username).zero?
                command = arr[1]&.downcase.to_sym
                params = arr[2]

            elsif msj.reply_to_message&.from&.id == @user.id # responde al bot
                command, params = text.split ' ', 2
                command.downcase!
            end
        end

        { command: command&.to_sym, params: params }
    end

    def obtener_enlace_usuario(id_chat, id_usuario)
        usuario = @tg.get_chat_member(chat_id: id_chat, user_id: id_usuario)
        usuario = Telegram::Bot::Types::ChatMember.new(usuario['result']).user
        enlace_usuario = crear_enlace(usuario)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        enlace_usuario = nil
        @logger.error(e)
    ensure
        return enlace_usuario || 'ay no c (' + usuario_id.to_s + ')'
    end

    def crear_enlace(usuario)
        if usuario.username
            "<a href='https://telegram.me/#{usuario.username}'>" \
                "#{usuario.username}</a>"
        elsif !usuario.first_name.empty?
            "<a href='tg://user?id=#{usuario.id}'>" \
                "#{html_parser(usuario.first_name)}</a>"
        else
            'ay no c (' + usuario.id.to_s + ')'
        end
    end

    def natural(numero)
        if numero.length < 25
            begin
                num = Integer(numero)
            rescue StandardError
                return false
            end

            return num if num > 0
        end

        false
    end

    def validar_grupo(type, chat_id, mensaje_id)
        if type == 'private'
            @tg.send_message(chat_id: chat_id, reply_to_message_id: mensaje_id,
                             text: 'Esto solo funciona en grupetes')
            return false

        elsif type == 'channel'
            return false

        end

        true
    end

    def validar_desarrollador(usuario_id, chat_id, mensaje_id, _text = nil, _id = nil)
        # Chequeo que quien llama al comando sea o desarrollador
        unless DEVS.include?(usuario_id)
            @tg.send_message(chat_id: chat_id, reply_to_message_id: mensaje_id,
                             text: 'Vos no podés usar esto pa')
            return false
        end

        true
    end

    def es_admin(usuario_id, chat_id, mensaje_id, text = nil, _id = nil)
        member = @tg.get_chat_member(chat_id: chat_id, user_id: usuario_id)
        member = Telegram::Bot::Types::ChatMember.new(member['result'])
        status = member.status

        # Chequeo que quien llama al comando sea admin del grupete
        # Si no lo es, manda mensaje de error
        if (status != 'administrator') && (status != 'creator')
            unless text.nil?
                @tg.send_message(chat_id: chat_id, reply_to_message_id: mensaje_id, text: text)
            end
            return false
        end

        true
    end

    def grupo_del_msj(msj)
        if msj.chat.title.nil?
            msj.chat.id.to_s
        else
            msj.chat.title + ' (' + msj.chat.id.to_s + ')'
        end
    end
end
