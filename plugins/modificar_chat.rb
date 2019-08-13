class Dankie
    add_handler Handler::Comando.new(:pin, :anclar, permitir_params: true)
    add_handler Handler::Comando.new(:anclar, :anclar, permitir_params: true,
                                                       descripción: 'Ancla el mensaje al que respondas '\
                                                   'en el grupete (agregar ''tranca'' para '\
                                                   'que no mande notificaciones al hacerlo)')
    add_handler Handler::Comando.new(:unpin, :desanclar)
    add_handler Handler::Comando.new(:desanclar, :desanclar,
                                     descripción: 'Ancla el mensaje al que respondas '\
                                                  'en el grupete (agregar ''tranca'' para '\
                                                  'que no mande notificaciones al hacerlo)')

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

        if cumple_req_modificar_chat(msj)
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
        elsif cumple_req_modificar_chat(msj, necesita_responder: false)
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
            error_permisos = "No hay ningún mensaje anclado #{TROESMAS.sample}"
            log_y_aviso(msj, error_permisos, al_canal: false)
        else
            raise
        end
    end

    private

    # Chequea que sea en un grupo, que responda a un mensaje (si corresponde)
    # y que tengan los permisos adecuados el bot y quien llama al comando.
    def cumple_req_modificar_chat(msj, necesita_responder: true)
        validar_grupo(msj.chat.type, msj.chat.id, msj.message_id) &&
            # Esto es una implicación, recordar que p => q es equivalente a
            # ¬p V q, y yo lo que quiero es que esto de verdadero cuando no se
            # necesite responder (p = false) o cuando se necesite responder y
            # se responda a un mensaje válido (p = true && q = true). Lo que no puede
            # valer es que necesite responder y el mensaje no sea válido (p = true
            # && q = false). Está hecho así para que se use esta función desde /desanclar
            (!necesita_responder || resp_msj_válido(msj)) &&
            tiene_permisos(msj, @user.id, :can_pin_messages,
                           'Necesito', 'No tengo permisos para pinear mensajes') &&
            tiene_permisos(msj, msj.from.id,
                           :can_pin_messages, 'Tenés que',
                           'No tenés permisos para pinear mensajes')
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
