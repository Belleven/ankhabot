require 'telegram/bot'

class Dankie
    add_handler CommandHandler.new(:help, :help, 'Envía la ayuda')

    def help(msg)
        
        text = "ola, soy @#{user.username} y puedo hacer todo esto :0\n"
        text << "versión: `#{VERSION}`\n"
        
        self.class.commands do |k, v|
            line = "/#{k} - #{v}\n"
            text << line
        end

        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'markdown', text: text)
    end
end
