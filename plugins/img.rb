class Dankie
    add_handler CommandHandler.new(:img, :search_image,
                                   description: 'Busca una imagen')

    def search_image(msg)
        args = get_command_params(msg) || msg.reply_to_message&.text || msg.reply_to_message&.caption

        unless args
            @tg.send_message(chat_id: msg.chat.id,
                             text: "dale #{TROESMAS.sample}, "\
                                  'decime que busco >:c')
            return
        end

        if args.size > 128
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message_id: msg.reply_to_message.message_id,
                             text: 'Muy largo el texto pa')
            return
        end

        images = @img.search_images args
        unless images
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message_id: msg.reply_to_message.message_id,
                             text: 'No mas imagenes por hoy uwu')
            return
        end
        link = images.sample
        link = images.sample until link.type == :image

        log(Logger::INFO, "Enviando imagen: <code>#{link.link}</code>",
            al_canal: true)
        @tg.send_photo(chat_id: msg.chat.id, photo: link.link)
    end
end
