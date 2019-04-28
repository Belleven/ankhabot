class Handler
    attr_reader :callback
end

class MessageHandler < Handler
end

class CommandHandler < Handler
    def initialize(cmd, callback, args)
        @cmd = cmd
        @callback = callback
        @allow_edited = args[:allow_edited] || false
    end

    def check_message(cmd, edit_date)
        if !@allow_edited && edit_date
            return false
        end

        if @cmd == cmd
            return true
        end
       
        return false
    end

end

class CallbackQueryHandler < Handler
end
