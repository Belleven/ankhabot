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

    # creo que esto es un dispatch si entendí bien
    def dispatch(msg)
        self.class.handlers.each do |handler|
            handler.check_message(self, msg)
        end
    end

    # Recibe un Hash con los datos de config.yml
    def initialize(args)
        @logger = Logger.new $stderr
        @canal_logging = args[:canal_logging]
        @tg = TelegramAPI.new args[:tg_token], @logger
        @redis = Redis.new port: args[:redis_port], host: args[:redis_host], password: args[:redis_pass]
        @img = ImageSearcher.new args[:google_image_key], args[:google_image_cx]
        @tz = TZInfo::Timezone.get args[:timezone]
        @user = Telegram::Bot::Types::User.new @tg.get_me['result'] # TODO: validar?
        @lastFM = LastFMParser.new args[:last_fm_api]
    end

    def run
        @tg.client.listen do |msg|
            next unless msg&.from&.id
            next if @redis.sismember('blacklist:global', msg.from.id.to_s)
            next if msg.is_a?(Telegram::Bot::Types::Message) &&
                    @redis.sismember("blacklist:#{msg.chat.id}", msg.from.id.to_s)

            dispatch(msg)

        rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
            begin
                log Logger::ERROR, excepcion_texto(e), al_canal: true
            rescue StandardError => e
                log Logger::FATAL, "EXCEPCIÓN LEYENDO LA EXCEPCIÓN", al_canal: true
            end
            retry
        
        rescue StandardError => e
            begin
                log Logger::FATAL, "EXCEPCIÓN LEYENDO LA EXCEPCIÓN", al_canal: true
            rescue StandardError => e
                log Logger::FATAL, "EXCEPCIÓN LEYENDO LA EXCEPCIÓN", al_canal: true
            end
        end
    end

    # Permite iterar sobre los comandos del bot, y sus descripciones
    def self.commands
        @handlers.each do |handler|
            next unless handler.is_a? CommandHandler

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
        texto = if !texto_excepcion.nil? && !texto_excepcion.empty? then html_parser(texto_excepcion) else "EXCEPCIÓN SIN NOMBRE" end
        lineas = "<pre>" + ('-' * 30) + "</pre>\n"

        unless excepcion.backtrace.nil?
            # La regex turbina esa es para no doxxearnos a los que usamos linux
            # / es para "/" => /home/ es para "/home/"
            # [^/]+ es para que detecte todos los caracteres que no sean "/" => /home/user/dankie/... queda
            # como /dankie/...
            texto << "\n" + lineas + lineas + "Rastreo de la excepción:\n" + lineas
            texto << "<pre>#{html_parser(excepcion.backtrace.join("\n").gsub(%r{/home/[^/]+}, '~'))}</pre>"
        end

        return texto
    end

    def log(nivel, texto, al_canal: false)
        if texto.nil? || texto.empty? 
            texto = "LOG SIN NOMBRE" 
        end
        
        @logger.log(nivel, texto)
        return unless al_canal == true   

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
        
        rescue StandardError => exc
            begin
                lineas = ('-' * 30) + "\n"
                texto_excepcion = lineas + "\nMientras se manejaba una excepción surgió otra:\n"
        
                excepcion = exc.to_s
                texto_excepcion << if !excepcion.nil? && !excepcion.empty?
                                    html_parser(exc.to_s)
                                else
                                    'ERROR SIN NOMBRE'
                                end
        
                texto_excepcion << "\n" + lineas + lineas + exc.backtrace.join("\n") + "\n" + lineas + lineas + "\n"
                @logger.log(Logger::FATAL, texto_excepcion)

            rescue StandardError => exc
                puts "\nFATAL, multiples excepciones.\n"
            end
    end

    def get_command(msg)
        cmd = _parse_command(msg)
        cmd[:command]
    end

    def get_command_params(msg)
        cmd = _parse_command(msg)
        cmd[:params]
    end

    private

    # Analiza un texto y se fija si es un comando válido, devuelve el comando
    # y el resto del texto
    def _parse_command(msg)
        unless (text = msg.text || msg.caption)
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

            elsif msg.reply_to_message&.from&.id == @user.id # responde al bot
                command, params = text.split ' ', 2
                command.downcase!
            end
        end

        { command: command&.to_sym, params: params }
    end

    def get_username_link(chat_id, user_id)
        user = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
        user = Telegram::Bot::Types::ChatMember.new(user['result']).user
        user_link = if user.username
                        "<a href='https://telegram.me/#{user.username}'>" \
                            "#{user.username}</a>"
                    elsif !user.first_name.empty?
                        "<a href='tg://user?id=#{user_id}'>" \
                            "#{html_parser(user.first_name)}</a>"
                    else
                        'ay no c (' + user_id + ')'
                    end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        user_link = nil
        @logger.error(e)
    ensure
        return user_link || 'ay no c (' + user_id + ')'
    end
end
