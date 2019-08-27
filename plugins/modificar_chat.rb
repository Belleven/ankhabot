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

    # Comando /unpin /desanclar
    def desanclar(msj)
        chat = obtener_chat(msj.chat.id)

        if chat.pinned_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'No hay ningún mensaje '\
                                   "anclado #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        elsif cumple_req_modificar_chat(msj, false, :can_pin_messages,
                                        'No tengo permisos para pinear mensajes')
            @tg.unpin_chat_message(chat_id: msj.chat.id)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Desancladísimo #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /not enough rights to unpin a message/
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                          'mientras se ejecutaba el comando, y por '\
                          'ahora no puedo desanclar mensajes'
            log_y_aviso(msj, error_permisos, al_canal: false)
        when /CHAT_NOT_MODIFIED/
            error_permisos = 'Desanclaron el mensaje mientras ejecutaba el comando, '\
                             "#{TROESMAS.sample}"
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

    def sacar_foto(msj)
        chat = obtener_chat(msj.chat.id)

        if chat.photo.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             text: "No hay ninguna foto en el chat #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        elsif cumple_req_modificar_chat(msj, false, :can_change_info,
                                        'No tengo permisos para cambiar '\
                                           'la foto del chat')
            @tg.delete_chat_photo(chat_id: msj.chat.id)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Foto eliminadísima #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /not enough rights to change chat photo/
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                          'mientras se ejecutaba el comando, y por '\
                          'ahora no puedo borrar la foto'
            log_y_aviso(msj, error_permisos, al_canal: false)
        when /CHAT_NOT_MODIFIED/
            error_permisos = 'Sacaron la foto del grupete mientras ejecutaba el '\
                             "comando, #{TROESMAS.sample}"
            log_y_aviso(msj, error_permisos, al_canal: false)
        else
            raise
        end
    end

    def cambiar_título(msj, params)
        if params.nil? || params.length.zero?
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Qué título le pongo, #{TROESMAS.sample}?",
                             reply_to_message_id: msj.message_id)
        elsif params.length > 255
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Hasta 255 caracteres, #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        elsif cumple_req_modificar_chat(msj, false, :can_change_info,
                                        'No tengo permisos para cambiar '\
                                           'el título del chat')
            @tg.set_chat_title(chat_id: msj.chat.id, title: params)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Título cambiadísimo #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /not enough rights to change chat title/
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                          'mientras se ejecutaba el comando, y por '\
                          'ahora no puedo cambiar el título'
            log_y_aviso(msj, error_permisos, al_canal: false)
        else
            raise
        end
    end

    def cambiar_descripción(msj, params)
        if params.length > 255
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Hasta 255 caracteres, #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        elsif cumple_req_modificar_chat(msj, false, :can_change_info,
                                        'No tengo permisos para cambiar '\
                                           'la descripción del chat')
        else
            @tg.set_chat_description(chat_id: msj.chat.id, title: params)
            @tg.send_message(chat_id: msj.chat.id,
                             text: "Descripción cambiadísima #{TROESMAS.sample}",
                             reply_to_message_id: msj.message_id)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s
        when /not enough rights to change chat description/
            error_permisos = 'Me restringieron los permisos o me sacaron el admin '\
                          'mientras se ejecutaba el comando, y por '\
                          'ahora no puedo cambiar el título'
            log_y_aviso(msj, error_permisos, al_canal: false)
        else
            raise
        end
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
end
