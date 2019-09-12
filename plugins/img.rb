class Dankie
    add_handler Handler::Comando.new(:img,
                                     :buscar_imagen,
                                     permitir_params: true,
                                     descripción: 'Busco una imagen')

    add_handler Handler::Comando.new(:imgtest,
                                     :img_test,
                                     permitir_params: true)

    def img_test(msj, parámetros)
        @tg.send_photo(chat_id: msj.chat.id, photo: parámetros) if parámetros
    end

    def buscar_imagen(msj, parámetros)
        args = parámetros || msj.reply_to_message&.text ||
               msj.reply_to_message&.caption

        # Chequeos sobre la entrada
        if args.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Dale #{TROESMAS.sample}, "\
                                   'decime qué busco >:c')
        elsif args.size > 89
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Muy largo el texto, #{TROESMAS.sample}")
        else
            # Busco en google
            resultados = @img.buscar_imagen args

            # Separo en casos
            case resultados

            # Caso bueno
            when Array
                enlace = resultados.shuffle!.find { |resultado| resultado.type == :image }

                if enlace
                    @logger.info("Enviando imagen: #{enlace.link}", al_canal: true)
                    @tg.send_photo(chat_id: msj.chat.id, photo: enlace.link)
                else
                    @tg.send_message(chat_id: msj.chat.id,
                                     reply_to_message_id: msj.message_id,
                                     text: 'No pude encontrar imágenes '\
                                      "de eso, #{TROESMAS.sample}")
                end

            # Casos malos
            when :sin_resultados
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: msj.message_id,
                                 text: "No pude encontrar nada #{TROESMAS.sample}, "\
                                     'probá con otra búsqueda')
            when :límite_diario
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: msj.message_id,
                                 text: 'No más imágenes por hoy uwu')
            when :error
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: msj.message_id,
                                 text: 'Hubo un error re turbina :c')
            end
        end
    end
end
