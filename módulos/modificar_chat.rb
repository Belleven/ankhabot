class Dankie
    add_handler Handler::Comando.new(
        :pin,
        :anclar,
        permitir_params: true,
        chats_permitidos: %i[group supergroup]
    )

    add_handler Handler::Comando.new(
        :anclar,
        :anclar,
        permitir_params: true,
        chats_permitidos: %i[group supergroup]
    )

    add_handler Handler::Comando.new(
        :fijar,
        :anclar,
        permitir_params: true,
        chats_permitidos: %i[group supergroup],
        descripción: 'Fijo el mensaje al que respondas en el grupete (agregá '\
                     "''tranca'' para que no mande notificaciones al hacerlo)"
    )

    add_handler Handler::Comando.new(:unpin, :desanclar)

    add_handler Handler::Comando.new(
        :desanclar,
        :desanclar,
        chats_permitidos: %i[group supergroup]
    )

    add_handler Handler::Comando.new(
        :desfijar,
        :desanclar,
        chats_permitidos: %i[group supergroup],
        descripción: 'Desfijo el mensaje fijado en el grupete'
    )

    # add_handler Handler::Comando.new(:ponerfoto, :poner_foto,
    #                                  chats_permitidos: %i[group supergroup],
    #                                  descripción: 'Cambio la foto del grupete')

    add_handler Handler::Comando.new(
        :sacarfoto,
        :sacar_foto,
        chats_permitidos: %i[group supergroup],
        descripción: 'Quito la foto del grupete'
    )

    add_handler Handler::Comando.new(
        :cambiartítulo,
        :cambiar_título,
        permitir_params: true,
        chats_permitidos: %i[group supergroup]
    )

    add_handler Handler::Comando.new(
        :cambiartitulo,
        :cambiar_título,
        permitir_params: true,
        chats_permitidos: %i[group supergroup],
        descripción: 'Cambio el título del grupete'
    )

    add_handler Handler::Comando.new(
        :cambiardescripcion,
        :cambiar_descripción,
        permitir_params: true,
        chats_permitidos: %i[group supergroup],
        descripción: 'Cambio la descripción del grupete'
    )

    add_handler Handler::Comando.new(
        :cambiardescripción,
        :cambiar_descripción,
        permitir_params: true,
        chats_permitidos: %i[group supergroup]
    )

    add_handler Handler::Comando.new(
        :borrardescripcion,
        :borrar_descripción,
        chats_permitidos: %i[group supergroup],
        descripción: 'Borro la descripción del grupete'
    )

    add_handler Handler::Comando.new(
        :borrardescripción,
        :borrar_descripción,
        chats_permitidos: %i[group supergroup]
    )

    # Comando /pin /anclar
    def anclar(msj, params)
        notificar = false

        if params && !(notificar = params.downcase == 'tranca')
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Si querés que nadie sea notificado '\
                                   "entonces acompañá el comando con ''tranca'', "\
                                   'si no, no acompañes el comando con nada',
                             reply_to_message_id: msj.message_id)
            return
        end

        if cumple_req_modificar_chat(msj, true, :can_pin_messages,
                                     'No tengo permisos para pinear mensajes')
            args_modif = {
                chat_id: msj.chat.id,
                message_id: msj.reply_to_message.message_id,
                disable_notification: notificar
            }

            modificar_chat(
                :pin_chat_message,
                args_modif,
                :manejar_excepciones_anclar,
                msj,
                'Ese mensaje ya está fijado'
            )
        end
    end

    # /ponerfoto
    # def poner_foto(msj) end

    # Comando /unpin /desanclar
    def desanclar(msj)
        quitar_elemento_chat(
            msj,
            :can_pin_messages,
            :unpin_chat_message,
            { chat_id: msj.chat.id },
            'Desfijadísimo'
        )
    end

    # Comando /sacarfoto
    def sacar_foto(msj)
        quitar_elemento_chat(
            msj,
            :can_change_info,
            :delete_chat_photo,
            { chat_id: msj.chat.id },
            'Foto eliminadísima'
        )
    end

    # Comandos /cambiartitulo y /cambiartítulo (notar la tilde)
    def cambiar_título(msj, params)
        texto = params || msj&.reply_to_message&.text || msj&.reply_to_message&.caption

        cambiar_texto_chat(
            msj,
            texto,
            :set_chat_title,
            { chat_id: msj.chat.id, title: texto }
        )
    end

    # Comando /cambiardesc
    def cambiar_descripción(msj, params)
        texto = params || msj&.reply_to_message&.text || msj&.reply_to_message&.caption

        cambiar_texto_chat(
            msj,
            texto,
            :set_chat_description,
            { chat_id: msj.chat.id, description: texto }
        )
    end

    def borrar_descripción(msj)
        if cumple_req_modificar_chat(msj, false, :can_change_info,
                                     'No tengo permisos para borrar la descripción')

            modificado = modificar_chat(
                :set_chat_description,
                { chat_id: msj.chat.id, description: '' },
                :manejar_excepciones_texto,
                msj,
                'No hay ninguna descripción que borrar'
            )

            if modificado
                @tg.send_message(
                    chat_id: msj.chat.id,
                    text: "Descripción borradísima #{TROESMAS.sample}",
                    reply_to_message_id: msj.message_id
                )
            end
        end
    end

    private

    # Chequea que sea en un grupo, que responda a un mensaje (si corresponde)
    # y que tenga los permisos adecuados quien llama al comando.
    def cumple_req_modificar_chat(msj, necesita_responder, permiso, error_permisos)
        (!necesita_responder || resp_msj_válido(msj)) &&
            tiene_permisos(msj, msj.from.id, permiso, 'Tenés que', error_permisos)
    end

    def resp_msj_válido(msj)
        if msj.reply_to_message.nil?
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'Tenés que responderle al mensaje que querés que fije',
                reply_to_message_id: msj.message_id
            )
            return false
        end

        tipos_msj_servicio = %i[
            new_chat_members left_chat_member new_chat_title new_chat_photo
            delete_chat_photo group_chat_created supergroup_chat_created
            channel_chat_created migrate_from_chat_id pinned_message invoice
            migrate_to_chat_id successful_payment connected_website passport_data
        ]

        # Prefiero chequear esto acá y no esperar a que rompa así nos ahorramos
        # un llamado a la api (igualmente agregué la excepción abajo por las dudas)
        tipos_msj_servicio.each do |tipo|
            atributo = msj.reply_to_message.send tipo
            next unless atributo && !(atributo.is_a?(Array) && atributo.empty?)

            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'No puedo fijar eventos de chat',
                reply_to_message_id: msj.message_id
            )
            return false
        end

        true
    end

    # Para quitar algo del chat
    def quitar_elemento_chat(msj, permiso, quitar, args_modif, texto_éxito)
        if cumple_req_modificar_chat(msj, false, permiso,
                                     'No tengo permisos para sacar eso')

            modificado = modificar_chat(
                quitar,
                args_modif,
                :manejar_excepciones_quitar,
                msj,
                'No puedo quitar algo que el chat no tiene'
            )

            if modificado
                @tg.send_message(
                    chat_id: msj.chat.id,
                    text: "#{texto_éxito} #{TROESMAS.sample}",
                    reply_to_message_id: msj.message_id
                )
            end
        end
    end

    # Para camabiar un texto del chat
    def cambiar_texto_chat(msj, texto, método_cambio, args_cambio)
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
        elsif cumple_req_modificar_chat(msj, false, :can_change_info,
                                        'No tengo permisos para cambiar eso')

            modificado = modificar_chat(
                método_cambio,
                args_cambio,
                :manejar_excepciones_texto,
                msj,
                'Lo que me estás pasando es el mismo texto que ya está ahora'
            )

            if modificado
                @tg.send_message(
                    chat_id: msj.chat.id,
                    reply_to_message_id: msj.message_id,
                    parse_mode: :html,
                    text: "Listo el pollo #{TROESMAS.sample}, "\
                          "cambiado a <b>#{html_parser texto}</b>"
                )
            end
        end
    end

    def modificar_chat(modif_chat, args_modif, manejar_exc, msj, error_mismo_elem)
        @tg.send modif_chat, args_modif
    rescue Telegram::Bot::Exceptions::ResponseError => e
        send manejar_exc, msj, e, error_mismo_elem
        nil
    end

    def manejar_excepciones_anclar(msj, excepción, error_mismo)
        case excepción.message
        when /not enough rights to (pin a message|manage pinned messages in the chat)/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'No tengo suficientes permisos para fijar un mensaje'
            )
            return
        when /CHAT_NOT_MODIFIED/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: error_mismo
            )
            return
        when /message to pin not found/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'No puedo fijar eso, no encontré el mensaje'
            )
            return
        when /a service message can't be pinned/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "No puedo fijar eventos de chat #{TROESMAS.sample}"
            )
            return
        end

        @logger.error excepción.to_s, al_canal: true
        @tg.send_message(
            chat_id: msj.chat.id,
            text: 'Hubo un error re turbina, probablemente '\
                    'no pude terminar de ejecutar el comando.',
            reply_to_message_id: msj.message_id
        )
    end

    def manejar_excepciones_quitar(msj, excepción, error_ya_quitado)
        case excepción.message
        when /not enough rights to (unpin a message|change chat photo)/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'No tengo suficientes permisos para hacer eso'
            )
            return
        when /CHAT_NOT_MODIFIED/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: error_ya_quitado
            )
            return
        when /message to unpin not found/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'No hay ningún mensaje para desfijar'
            )
            return
        end

        @logger.error excepción.to_s, al_canal: true
        @tg.send_message(
            chat_id: msj.chat.id,
            text: 'Hubo un error re turbina, probablemente '\
                    'no pude terminar de ejecutar el comando.',
            reply_to_message_id: msj.message_id
        )
    end

    def manejar_excepciones_texto(msj, excepción, error_mismo_texto)
        case excepción.message
        when /not enough rights to (set|change) chat (title|description)/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'No tengo suficientes permisos para hacer eso'
            )
            return
        when /chat (title|description) is not modified/
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: error_mismo_texto
            )
            return
        end

        @logger.error excepción.to_s, al_canal: true
        @tg.send_message(
            chat_id: msj.chat.id,
            text: 'Hubo un error re turbina, probablemente '\
                    'no pude terminar de ejecutar el comando.',
            reply_to_message_id: msj.message_id
        )
    end
end
