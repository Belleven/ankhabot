class Dankie
    add_handler Handler::Comando.new(:img, :search_image,
                                     descripción: 'Busco una imagen')

    def search_image(msj)
        args = get_command_params(msj) || msj.reply_to_message&.text ||
               msj.reply_to_message&.caption

        unless args
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Dale #{TROESMAS.sample}, "\
                                  'decime qué busco >:c')
            return
        end

        if args.size > 128
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'Muy largo el texto pa')
            return
        end

        imágenes = @img.search_images args
        unless imágenes
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No mas imágenes por hoy uwu')
            return
        end
        enlace = imágenes.sample
        enlace = imágenes.sample until enlace.type == :image

        @logger.info(
            "Enviando imagen: #{enlace.link}",
            al_canal: true
        )
        @tg.send_photo(chat_id: msj.chat.id, photo: enlace.link)
    end
end
