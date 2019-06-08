class Dankie
    add_handler CommandHandler.new(:deusvult, :deusvult,
                                   description: 'Envía un meme de cruzadas')

    def deusvult(msg)
        @tg.send_photo(chat_id: msg.chat.id, photo: DEUS_VULT.sample)
    end
end
