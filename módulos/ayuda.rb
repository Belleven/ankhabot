require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(:ayuda, :ayuda, descripción: 'Mando la ayuda')
    add_handler Handler::Comando.new(:help, :ayuda)

    def ayuda(msj)
        texto = "ola, soy @#{user.username} y puedo hacer todo esto :0\n"
        texto << "versión: <code>#{VERSIÓN}</code>\n"

        self.class.commands do |comando, desc|
            texto << "/#{comando} - #{desc}\n"
        end

        @tg.send_message(chat_id: msj.chat.id,
                         parse_mode: :html,
                         text: texto)
    end
end
