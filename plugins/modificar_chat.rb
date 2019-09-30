class Dankie
    add_handler Handler::Comando.new(:pin, :anclar, permitir_params: true,
                                                    chats_permitidos: %i[group supergroup])
    add_handler Handler::Comando.new(:anclar, :anclar, permitir_params: true,
                                                       chats_permitidos: %i[group supergroup],
                                                       descripción: 'Anclo el mensaje al que respondas '\
                                                  "en el grupete (agregá ''tranca'' "\
                                                  'para que no mande notificaciones '\
                                                  'al hacerlo)')
    add_handler Handler::Comando.new(:unpin, :desanclar)
    add_handler Handler::Comando.new(:desanclar, :desanclar,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Desanclo el mensaje anclado '\
                                                  'en el grupete')
    # add_handler Handler::Comando.new(:ponerfoto, :poner_foto,
    #                                  chats_permitidos: %i[group supergroup],
    #                                  descripción: 'Cambio la foto del grupete')
    add_handler Handler::Comando.new(:sacarfoto, :sacar_foto,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Quito la foto del grupete')
    add_handler Handler::Comando.new(:cambiartítulo, :cambiar_título,
                                     permitir_params: true,
                                     chats_permitidos: %i[group supergroup])
    add_handler Handler::Comando.new(:cambiartitulo, :cambiar_título,
                                     permitir_params: true,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Cambio el título del grupete')
    add_handler Handler::Comando.new(:cambiardesc, :cambiar_descripción,
                                     permitir_params: true,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Cambio la descripción del grupete')

    # Comando /pin /anclar
    def anclar(msj, params)
        notificar = false

        if params
            if params.length == 6 && params.downcase == 'tranca'
                notificar = true
            else
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'Si querés que nadie sea notificado '\
                                 "entonces acompañá el comando con ''tranca'', "\
                                 'si no, no acompañes el comando con nada',
                                 reply_to_message_id: msj.message_id)
                return
            end
        end

        if cumple_req_modificar_chat(msj, true, :can_pin_messages,
                                     'No tengo permisos para pinear mensajes')
            @tg.pin_chat_message(chat_id: msj.chat.id,
                                 message_id: msj.reply_to_message.message_id,
                                 disable_notification: notificar)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /not enough rights to pin a message/
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                          'mientras se ejecutaba el comando, y por '\
                          'ahora no puedo anclar mensajes'
            log_y_aviso(msj, error_permisos, al_canal: false)
        when /CHAT_NOT_MODIFIED/
            error_permisos = 'Estás tratando de hacer que ancle un mensaje que '\
                             "ya está anclado #{TROESMAS.sample}"
            log_y_aviso(msj, error_permisos, al_canal: false)
        when /message to pin not found/
            error_permisos = "No puedo anclar eso #{TROESMAS.sample}, "\
                             'no encontré el mensaje'
            log_y_aviso(msj, error_permisos, al_canal: false)
        else
            raise
        end
    end

    # /ponerfoto
    def poner_foto(msj)
        id_imagen = nil
        # Si el comando viene en el 'caption' de una imagen
        if !msj.photo.empty?
            id_imagen = msj.photo[-1].file_id
        elsif msj.reply_to_message

            # Si están respondiendo a una imagen
            if !msj.reply_to_message.photo.empty?
                id_imagen = msj.reply_to_message.photo[-1].file_id
            # Si están respondiendo el evento de chat de cambio de imagen del grupo
            elsif !msj.reply_to_message.new_chat_photo.empty?
                id_imagen = msj.reply_to_message.new_chat_photo[-1].file_id
            end

        end

        if id_imagen.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Respondele a una imagen #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
            return
        elsif cumple_req_modificar_chat(msj, false, :can_change_info,
                                        'No tengo permisos para cambiar '\
                                        'la imagen del grupete')
            # TODO: usar identificador de imagen para cada tipo posible
            descargar_archivo_tg(id_archivo, '')

            # TODO: descargar y subir el archivete
            # lectura = ImageList.new("a.png")
            # @tg.set_chat_photo(chat_id: msj.chat.id, photo: lectura)
        end
        # rescue
        # case e.to_s
        # when /asdfasdf/
        # TODO: manejar excepciones virgochas
        # else
        #    raise
        # end
    end

    # Comando /unpin /desanclar
    def desanclar(msj)
        # Función a ejecutar
        quitar = proc do |id_chat|
            @tg.unpin_chat_message(chat_id: id_chat)
        end
        # Textos para responder
        error_no_tiene = "No hay ningún mensaje anclado #{TROESMAS.sample}"
        texto_éxito = 'Desancladísimo'
        error_mientras = 'Desanclaron el mensaje mientras ejecutaba el '\
                         "comando, #{TROESMAS.sample}"

        quitar_elemento_chat(msj, quitar, :pinned_message, error_no_tiene,
                             texto_éxito, error_mientras, :can_pin_messages)
    end

    # Comando /sacarfoto
    def sacar_foto(msj)
        # Función a ejecutar
        quitar = proc do |id_chat|
            @tg.delete_chat_photo(chat_id: id_chat)
        end
        # Textos para responder
        error_no_tiene = "No hay ninguna foto en el chat #{TROESMAS.sample}"
        texto_éxito = 'Foto eliminadísima'
        error_mientras = 'Sacaron la foto del grupete mientras ejecutaba el '\
                         "comando, #{TROESMAS.sample}"

        quitar_elemento_chat(msj, quitar, :photo, error_no_tiene,
                             texto_éxito, error_mientras, :can_change_info)
    end

    # Comandos /cambiartitulo y /cambiartítulo (notar la tilde)
    def cambiar_título(msj, params)
        modificador = proc do |chat_id, título|
            @tg.set_chat_title(chat_id: chat_id, title: título)
        end
        cambiar_texto_chat(msj, params, modificador, :título_rep)
    end

    # Comando /cambiardesc
    def cambiar_descripción(msj, params)
        modificador = proc do |chat_id, descripción|
            @tg.set_chat_description(chat_id: chat_id, description: descripción)
        end
        cambiar_texto_chat(msj, params, modificador, :descripción_rep)
    end

    private

    # Chequea que sea en un grupo, que responda a un mensaje (si corresponde)
    # y que tengan los permisos adecuados el bot y quien llama al comando.
    def cumple_req_modificar_chat(msj, necesita_responder,
                                  permiso, error_permisos)
        # Esto es una implicación, recordar que p => q es equivalente a
        # ¬p V q, y yo lo que quiero es que esto de verdadero cuando no se
        # necesite responder (p = false) o cuando se necesite responder y
        # se responda a un mensaje válido (p = true && q = true). Lo que no puede
        # valer es que necesite responder y el mensaje no sea válido (p = true
        # && q = false). Está hecho así para que se use esta función desde /desanclar
        (!necesita_responder || resp_msj_válido(msj)) &&
            tiene_permisos(msj, @user.id, permiso, 'Necesito', error_permisos) &&
            tiene_permisos(msj, msj.from.id, permiso, 'Tenés que', error_permisos)
    end

    def resp_msj_válido(msj)
        if msj.reply_to_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que responderle al mensaje '\
                                     'que querés que ancle',
                             reply_to_message_id: msj.message_id)
            return false
        end

        chat = obtener_chat(msj.chat.id)
        if chat.pinned_message &&
           chat.pinned_message.message_id == msj.reply_to_message.message_id

            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Estás tratando de hacer que ancle un mensaje que '\
                                     "ya está anclado #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
            return false
        else
            return true
        end
    end

    # Para camabiar un texto del chat
    def cambiar_texto_chat(msj, params, modificador, texto_no_repetido)
        texto = params || msj&.reply_to_message&.text || msj&.reply_to_message&.caption
        # Me fijo si no hay parámetros
        if texto.nil? || texto.length.zero?
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Qué tengo que poner, #{TROESMAS.sample}?",
                             reply_to_message_id: msj.message_id)
        # Si los parámetros superan lo permitido
        elsif texto.length > 255
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Hasta 255 caracteres, #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        # Chequeo que el texto que me pasan no sea el mismo que está actualmente
        # en el grupete
        elsif !send(texto_no_repetido, msj, texto) &&
              cumple_req_modificar_chat(msj, false, :can_change_info,
                                        'No tengo permisos para cambiar eso')
            # Cambio lo que tenga que cambiar
            modificador.call(msj.chat.id, texto)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Listo el pollo #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /not enough rights to (set|change) chat (title|description)/
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                          'mientras se ejecutaba el comando, y por '\
                          'ahora no puedo cambiar nada'
            log_y_aviso(msj, error_permisos, al_canal: false)
        when /chat (title|description) is not modified/
            error_permisos = 'Justo pusieron lo mismo que vos me pasaste mientras '\
                             'procesaba el comando'
            log_y_aviso(msj, error_permisos, al_canal: false)
        else
            raise
        end
    end

    # Para quitar algo del chat
    def quitar_elemento_chat(msj, quitar, elemento, error_no_tiene,
                             texto_éxito, error_mientras, permiso)
        if chat_tiene(msj, elemento, error_no_tiene) &&
           cumple_req_modificar_chat(msj, false, permiso,
                                     'No tengo permisos para sacar eso')
            quitar.call(msj.chat.id)
            @tg.send_message(chat_id: msj.chat.id,
                             text: texto_éxito + ' ' + TROESMAS.sample,
                             reply_to_message_id: msj.message_id)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /not enough rights to (unpin a message|change chat photo)/
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                             'mientras se ejecutaba el comando, y por '\
                             'ahora no puedo hacer eso'
            log_y_aviso(msj, error_permisos, al_canal: false)
        when /CHAT_NOT_MODIFIED/
            log_y_aviso(msj, error_mientras, al_canal: false)
        else
            raise
        end
    end

    def título_rep(msj, params)
        if (se_repite = (msj.chat.title == params))
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'El título que me pasas es el mismo que ya tiene '\
                                    "el chat, #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        end
        se_repite
    end

    def descripción_rep(msj, params)
        chat = obtener_chat(msj.chat.id)
        if (se_repite = (chat.description == params))
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'La descripción que me pasás es la misma que ya '\
                                    "tiene el chat, #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        end
        se_repite
    end

    def chat_tiene(msj, elemento, error_no_tiene)
        chat = obtener_chat(msj.chat.id)
        unless (tiene = chat.send(elemento))
            @tg.send_message(chat_id: msj.chat.id,
                             text: error_no_tiene,
                             reply_to_message_id: msj.message_id)
        end
        tiene
    end
end
