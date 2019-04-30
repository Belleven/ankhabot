require_relative 'telegram.rb'
require 'redis'
require 'tzinfo'
require 'set'

class Dankie
    attr_reader :tg, :logger, :redis, :reddit, :user
    TROESMAS = File.readlines('troesmas.txt').map(&:chomp)
    REKT = File.readlines('rekt.txt').map(&:chomp)

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
                if handler.check_message(msg)
                    send(handler.callback, msg)
                end
            end

            cmd = parse_command(msg)
            return unless cmd && cmd[:command]
            @@command_handlers.each do |handler|
                if handler.check_message(cmd[:command], msg.edit_date)
                    send(handler.callback, msg)
                end
            end
=begin
        when Telegram::Bot::Types::CallbackQuery
            @@callback_query_handlers.each do |handler|
                if handler.check_message(msg)
                    send(handler.callback, msg)
                end
            end
=end
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
        @developers = Set.new([263078683, 240524686, 267832653, 98631116, 196535916])
    end

    def run
        @tg.client.listen do |msg|
            next if not msg&.from&.id
            next if @redis.sismember("bloqueados", msg.from.id.to_s)
            
            dispatch(msg)

        rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
            logger.error e
            retry
        end
    end

    # Permite iterar sobre los comandos del bot, y sus descripciones
    def self.commands
        @@command_handlers.each do |handler|
            if handler.description
                yield handler.cmd, handler.description
            end
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
        user = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
        user = Telegram::Bot::Types::ChatMember.new(user['result']).user
        user_link = if user.username
                        "<a href='https://telegram.me/#{user.username}'>" +
                            "#{user.username}</a>"
                    elsif not user.first_name.empty?
                        "<a href='tg://user?id=#{user_id}'>" +
                            "#{user.first_name}</a>"
                    else
                        "ay no c (" + user_id + ")"
                    end
    rescue Telegram::Bot::Exceptions::ResponseError, e
        user_link = nil
        @logger.error(e)
    ensure
        user_link || "ay no c (ID: " + user_id + ")"
    end


end
