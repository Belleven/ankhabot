require 'telegram/bot'
require 'tzinfo'

class Dankie
    attr_reader :logger, :redis, :reddit, :user, :blacklist_arr
    @@commands = {}
    TROESMAS = File.readlines('troesmas.txt').map(&:chomp)
    REKT = File.readlines('rekt.txt').map(&:chomp)

    def initialize(api, logger, redis, reddit)
        @api = api
        @logger = logger
        @redis = redis
        @reddit = reddit
        # TODO: Pasar este string a algun archivo de configuracion global
        @tz = TZInfo::Timezone.get('America/Argentina/Buenos_Aires')
        @user = Telegram::Bot::Types::User.new(get_me['result']) # TODO: validar?

        @blacklist_arr = []
        @blacklist_populated = false
    end

    # Con esta función agregás un comando para el comando de ayuda,
    # y su descripción
    def self.command(args)
        raise ArgumentException unless args.is_a? Hash

        @@commands.merge!(args)
    end

    def self.commands
        @@commands.each do |k, v|
            yield k, v
        end
    end

    # Analiza un texto y se fija si es un comando válido, devuelve el comando
    # y el resto del texto
    def parse_command(msg)
        return unless (text = msg.text || msg.caption)

        if text.start_with? '/' # "/cmd params" o "/cmd@bot params"
            command, params = text.split ' ', 2
            command.downcase!
            command.gsub!(%r{^/([a-z]+)(@#{@user.username.downcase})?}, '\\1')

            return { command: command.to_sym, params: params }

        elsif ['!', '>'].include? text[0] # "!cmd params" o ">cmd params"
            command, params = text[1..-1].split ' ', 2
            command.downcase!

            return { command: command.to_sym, params: params }

        else 
            arr = text.split(' ', 3) # ["user", "comando", "params"]
            if arr.first.downcase == @user.username.downcase
                return { command: arr[1].downcase.to_sym, params: arr[2] || nil }

            elsif msg.reply_to_message&.from&.id == @user.id # responde al bot
                command, params = text.split ' ', 2
                command.downcase!

                return { command: command.to_sym, params: params }
            end
        end

        return { command: nil, params: nil }
    end

    def get_username_link(chat_id, user_id)
        user = get_chat_member(chat_id: chat_id, user_id: user_id)
        user = Telegram::Bot::Types::ChatMember.new(user['result']).user
        user_link = if user.username
                        "<a href='https://telegram.me/#{user.username}'>" +
                        "#{user.username}</a>"
                    else
                        "<b>#{user.first_name}</b>"
        end
    rescue Telegram::Bot::Exceptions::ResponseError, e
        user_link = nil
        @logger.error(e)
    ensure
        user_link || 'ay no c'
    end






    # tengo acceso a toda la api de telegram (bot.api) desde la clase Dankie
    # suena horrible pero está bueno y pude hacer unos rescue
    def method_missing(method_name, *args)
        super unless @api.respond_to?(method_name)
        @api.send(method_name, *args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
        @logger.error(e)
        @logger.error(e.display)
        @logger.error(e.backtrace)
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error(e)
        @logger.error(e.display)
        @logger.error(e.backtrace)
        raise e
    end

    def respond_to_missing?(method_name)
        @api.respond_to?(method_name) || super
    end
end
