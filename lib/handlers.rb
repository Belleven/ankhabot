class Handler
    attr_reader :callback
end

class MessageHandler < Handler
    MSG_TYPES = %i[text audio document game photo
                   sticker video voice video_note contact
                   location venue poll].freeze

    def initialize(callback, args = {})
        @callback = callback
        @allow_edited = args[:allow_edited] || false
        @allow_channel = args[:allow_channel] || false
        @msg_types = args[:types] || MSG_TYPES
    end

    def check_message(msg)
        return false if !@allow_edited && msg.edit_date

        return false if !@allow_channel && msg.chat.type == 'channel'

        msg_type = false
        @msg_types.each do |type|
            msg_type = msg.send type
            break if msg_type
        end

        msg_type ? true : false
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
        return false if !@allow_edited && edit_date

        return false if @cmd != cmd

        true
    end
end

class CallbackQueryHandler < Handler
end
