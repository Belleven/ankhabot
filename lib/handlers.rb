class Handler
end

class MessageHandler < Handler
    MSG_TYPES = %i[text audio document game photo
                   sticker video voice video_note contact
                   location venue poll].freeze

    def initialize(callback, args = {})
        @callback = callback
        @allow_edited = args[:allow_edited] || false
        @allowed_chats = args[:allowed_chats]&.map(&:to_s) || %w[private group supergroup] # 'channel' es otra opción
        @msg_types = args[:types] || MSG_TYPES
    end

    def check_message(bot, msg)
        return unless msg.is_a? Telegram::Bot::Types::Message
        return if !@allow_edited && msg.edit_date

        return unless @allowed_chats.include?(msg.chat.type)

        msg_type = nil
        @msg_types.each do |type|
            msg_type = msg.send type
            break if msg_type
        end

        return unless msg_type

        bot.public_send(@callback, msg)
    end
end

class CommandHandler < Handler
    attr_reader :cmd, :description
    def initialize(cmd, callback, args = {})
        @cmd = cmd
        @callback = callback
        @description = args[:description]
        @allow_params = args[:allow_params] || false
        @allow_edited = args[:allow_edited] || false
    end

    def check_message(bot, msg)
        return unless msg.is_a? Telegram::Bot::Types::Message

        return if !@allow_edited && msg.edit_date

        cmd = bot.get_command(msg)
        return if @cmd != cmd

        bot.logger.info "CommandHandler: comando \"#{@cmd}\" en #{msg.chat.id}"
        if @allow_params
            bot.public_send(@callback, msg, bot.get_command_params(msg))
        else
            bot.public_send(@callback, msg)
        end
    end
end

class CallbackQueryHandler < Handler
    def initialize(callback, patrón, _args = {})
        @callback = callback
        @patrón = patrón
    end

    def check_message(bot, msg)
        return unless msg.is_a? Telegram::Bot::Types::CallbackQuery

        return unless @patrón =~ msg.data

        bot.logger.info "CallbackQueryHandler: patrón #{@patrón} en #{msg.chat.id}"
        bot.public_send(@callback, msg)
    end
end
