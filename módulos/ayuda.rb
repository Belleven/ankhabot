class Dankie
    add_handler Handler::Comando.new(:ayuda, :ayuda, descripción: 'Mando la ayuda')
    add_handler Handler::Comando.new(:help, :ayuda)

    def ayuda(msj)
        texto = "ola, soy @#{@user.username} y puedo hacer todo esto :0\n"
        texto << "versión: <code>#{VERSIÓN}</code>\n"

        handlers = Dankie.comandos.values.filter(&:descripción)
        handlers.sort! { |handler_a, handler_b| handler_a.cmd <=> handler_b.cmd }
        handlers.map! { |handler| "/#{handler.cmd} - #{handler.descripción}" }
        texto << handlers.join("\n")

        @tg.send_message(
            chat_id: msj.chat.id,
            parse_mode: :html,
            text: texto
        )
    end
end
