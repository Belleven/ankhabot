require 'telegram/bot'

class Dankie
    command help: 'Este mensaje'

    def help(msg)
        return unless msg.is_a?(Telegram::Bot::Types::Message)

        cmd = parse_command(msg)
        return unless cmd && (cmd[:command] == :help)

        text = "TODO: poner algún texto acá\n"
        text << "versión: `#{VERSION}`\n"

        self.class.commands do |k, v|
            line = "/#{k} - #{v}\n"
            text << line # Mas adelante validar que text no se pase de los 4096 caracteres pero no creo que pase
        end

        send_message(chat_id: msg.chat.id,
                     parse_mode: 'markdown',
                     text: text)
    end
end
