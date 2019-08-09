require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(:help, :help, descripción: 'Envía la ayuda')

    def help(msj)
        texto = "ola, soy @#{user.username} y puedo hacer todo esto :0\n"
        texto << "versión: <code>#{VERSION}</code>\n"

        self.class.commands do |k, v|
            línea = "/#{k} - #{v}\n"
            texto << línea
        end

        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html, text: texto)
    end
end
