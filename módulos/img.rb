class Dankie
    add_handler Handler::Comando.new(:img,
                                     :buscar_imagen,
                                     permitir_params: true,
                                     descripción: 'Busco una imagen')

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
            analizar_resultados(resultados, args, msj)
        end
    end

    private

    def analizar_resultados(resultados, args, msj)
        case resultados
            # Caso bueno
        when Array
            resultados.shuffle!.filter! { |resultado| resultado.type == :image }
            responder_resultados_array(resultados, args, msj)

        # Casos malos
        when :sin_resultados
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "No pude encontrar nada #{TROESMAS.sample}, "\
                      'probá con otra búsqueda'
            )
        when :límite_diario
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'No más imágenes por hoy uwu'
            )
        when :error
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Hubo un error re turbina :c'
            )
        end
    end

    def responder_resultados_array(resultados, args, msj)
        resultados.each do |enlace|
            loggeo = "Búsqueda: #{args}\nImagen: #{enlace.link}"
            @logger.info(loggeo, al_canal: false)

            begin
                return @tg.send_photo(chat_id: msj.chat.id, photo: enlace.link)
            rescue Telegram::Bot::Exceptions::ResponseError => e
                e = e.to_s

                log = if e.include?('failed to get HTTP URL content')
                          "Error al querer mandar este link: #{enlace.link}"
                      else
                          "Error desconocido: #{e}"
                      end
                @logger.info(log, al_canal: false)
            end
        end

        @tg.send_message(
            chat_id: msj.chat.id,
            reply_to_message_id: msj.message_id,
            text: "No pude encontrar imágenes de eso, #{TROESMAS.sample}"
        )
    end
end
