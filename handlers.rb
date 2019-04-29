class Handler
    attr_reader :callback
end

class MessageHandler < Handler
    def initialize(callback, args = {})
        @callback = callback
        @allow_edited = args[:allow_edited] || false
        @allow_channel = args[:allow_channel] || false
    end

    def check_message(msg)
        if !@allow_edited && msg.edit_date
            return false
        end

        if !@allow_channel && msg.chat.type == 'channel'
            return false
        end

        return true
    end
end

class CommandHandler < Handler
    attr_reader :cmd, :description
    def initialize(cmd, callback, desc = nil, args = {})
        @cmd = cmd
        @callback = callback
        @description = desc
        @allow_edited = args[:allow_edited] || false
    end

    def check_message(cmd, edit_date)
        if !@allow_edited && edit_date
            return false
        end

        if @cmd != cmd
            return false
        end
       
        return true
    end

end

class CallbackQueryHandler < Handler
end
