class Dankie
    add_handler Handler::Comando.new(:callefuegos, :callefuegos,
                                     descripción: 'Envía un meme de Callejeros')

    def callefuegos(msg)
        @tg.send_photo(chat_id: msg.chat.id, photo: CALLEFUEGOS.sample)
    end
end
