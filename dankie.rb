require_relative 'telegram.rb'
require 'redis'
require 'tzinfo'
require 'set'

class Dankie
    attr_reader :tg, :logger, :redis, :reddit, :user
    TROESMAS = File.readlines('troesmas.txt').map(&:chomp)
    REKT = File.readlines('rekt.txt').map(&:chomp)
    DEVS = Set.new([240_524_686, # Luke
                    98_631_116,  # M
                    263_078_683, # Santi
                    267_832_653, # Galerazo
                    196_535_916, # Ale
                    298_088_760, # Mel
                    36_557_595 # Bruno
    ]).freeze

    def self.add_handler(handler)
        case handler
        when MessageHandler
            @@message_handlers ||= []
            @@message_handlers << handler
        when CommandHandler
            @@command_handlers ||= []
            @@command_handlers << handler
        when CallbackQueryHandler
            @@callback_query_handlers ||= []
            @@callback_query_handlers << handler
        end
    end

    # creo que esto es un dispatch si entendí bien
    def dispatch(msg)
        case msg
        when Telegram::Bot::Types::Message
            @@message_handlers.each do |handler|
                send(handler.callback, msg) if handler.check_message(msg)
            end

            cmd = parse_command(msg)
            return unless cmd && cmd[:command]

            @@command_handlers.each do |handler|
                next if msg.chat.type == 'channel'

                if handler.check_message(cmd[:command], msg.edit_date)
                        send(handler.callback, msg)
                end
            end
            #         when Telegram::Bot::Types::CallbackQuery
            #             @@callback_query_handlers.each do |handler|
            #                 if handler.check_message(msg)
            #                     send(handler.callback, msg)
            #                 end
            #             end
        end
    end

    #    def initialize(api, logger, redis, reddit)
    # Recibe un Hash con :tg_token, :redis_host, :redis_port, :redis_pass
    def initialize(args)
        @logger = Logger.new $stderr
        @tg = TelegramAPI.new args[:tg_token], @logger
        @redis = Redis.new port: args[:redis_port], host: args[:redis_host], password: args[:redis_pass]
        @tz = TZInfo::Timezone.get args[:timezone]
        @user = Telegram::Bot::Types::User.new(@tg.get_me['result']) # TODO: validar?
        @lastfm = "http://ws.audioscrobbler.com/2.0/?method=user.getrecenttracks&format=json&limit=1&api_key=" + args[:last_fm_api] + "&user="
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
        @@command_handlers.each do |handler|
            yield handler.cmd, handler.description if handler.description
        end
    end

    private

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
            if arr.first.casecmp(@user.username).zero?
                return { command: arr[1].downcase.to_sym, params: arr[2] || nil }

            elsif msg.reply_to_message&.from&.id == @user.id # responde al bot
                command, params = text.split ' ', 2
                command.downcase!

                return { command: command.to_sym, params: params }
            end
        end

        { command: nil, params: nil }
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
    rescue Telegram::Bot::Exceptions::ResponseError, e
        user_link = nil
        @logger.error(e)
    ensure
        user_link || 'ay no c (ID: ' + user_id + ')'
    end
end
