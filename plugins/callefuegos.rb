class Dankie
    add_handler CommandHandler.new(:callefuegos, :callefuegos,
                                   description: 'Envía un meme de Callejeros')

    def callefuegos(msg)
        @tg.send_photo(chat_id: msg.chat.id, photo: CALLEFUEGOS.sample)
    end
end
