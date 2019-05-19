class Dankie
    add_handler CommandHandler.new(:callefuegos, :callefuegos,
                                   'Envía un meme de Callejeros')
    
    private

    def callefuegos(msg)
        @tg.send_photo(chat_id: msg.chat.id, photo: CALLEFUEGOS.sample)
    end
end 
