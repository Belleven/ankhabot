class Dankie
    add_handler CommandHandler.new(:img, :search_image, 'Busca una imagen')

    private

    def search_image(msg)
        cmd = parse_command(msg)

        unless cmd[:params]
            @tg.send_message(chat_id: msg.chat.id,
                             text: "dale #{TROESMAS.sample}, "\
                                  'decime que busco >:c')
            return
        end

        if cmd[:params].size > 128
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message_id: msg.reply_to_message.message_id,
                             text: 'Muy largo el texto pa')
            return
        end

        images = @img.search_images cmd[:params]
        unless images
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message_id: msg.reply_to_message.message_id,
                             text: 'No mas imagenes por hoy uwu')
            return
        end
        link = images.sample
        link = images.sample until link.type == :image

        @logger.info("Enviando imágen: #{link.link}")
        @tg.send_photo(chat_id: msg.chat.id, photo: link.link)
    end
end
