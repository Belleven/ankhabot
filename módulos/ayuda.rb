require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(:ayuda, :ayuda, descripción: 'Mando la ayuda')
    add_handler Handler::Comando.new(:help, :ayuda)

    def ayuda(msj)
        texto = "ola, soy @#{@user.username} y puedo hacer todo esto :0\n"
        texto << "versión: <code>#{VERSIÓN}</code>\n"

        Dankie.comandos.each do |_comando, handler|
            texto << "/#{handler.cmd} - #{handler.descripción}\n" if handler.descripción
        end

        @tg.send_message(
            chat_id: msj.chat.id,
            parse_mode: :html,
            text: texto
        )
    end
end
