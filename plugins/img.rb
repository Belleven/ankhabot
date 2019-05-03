class Dankie
    add_handler CommandHandler.new(:img, :search_image, 'Busca una imagen')

    private

    def search_image(msg)
        cmd = parse_command(msg)

        unless cmd[:params]
            @tg.send_message(chat_id: msg.chat.id,
                             text: "dale #{TROESMAS.sample}, "\
                                  'decime que busco >:c')
        end

        images = @img.search_images cmd[:params]
        unless images
            @tg.send_message(chat_id: msg.chat.id,
                             text: 'No mas imagenes por hoy uwu')
        end

        @tg.send_photo(chat_id: msg.chat.id, photo: images.sample)
    end
end
