require_relative 'version.rb'
require_relative 'handlers.rb'
require_relative 'telegram.rb'
require_relative 'images.rb'
require_relative 'last_fm_parser.rb'
require 'redis'
require 'tzinfo'
require 'set'

class Dankie
    attr_reader :tg, :logger, :redis, :reddit, :user
    TROESMAS = File.readlines('resources/troesmas.txt').map(&:chomp).freeze
    REKT = File.readlines('resources/rekt.txt').map(&:chomp).freeze
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
            next if @redis.sismember("blacklist:#{msg.chat.id}", msg.from.id.to_s)

            dispatch(msg)

        rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
            logger.error e
            retry
        end
    end

    # Permite iterar sobre los comandos del bot, y sus descripciones
    def self.commands
        @handlers.each do |handler|
            next unless handler.is_a? CommandHandler

            yield handler.cmd, handler.description if handler.description
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
                            "#{user.first_name}</a>"
                    else
                        'ay no c (' + user_id + ')'
                    end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        user_link = nil
        @logger.error(e)
    ensure
        user_link || 'ay no c (ID: ' + user_id + ')'
    end
end
