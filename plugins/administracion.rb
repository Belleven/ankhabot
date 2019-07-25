class Dankie
    add_handler CommandHandler.new(:rajar, :rajar,
                                   description: 'Echo al usuario que me digas')

    def rajar(msj)
        cumple, miembro = cumple_requisitos(msj, true)

        if cumple
            id_afectada = msj.reply_to_message.from.id

            if miembro['status'] == 'left' || miembro['status'] == 'kicked' ||
               (miembro['status'] == 'restricted' && miembro['is_member'])

                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No voy a echar a alguien que no está en el grupo',
                                 reply_to_message: msj.message_id)
            else

                @tg.kick_chat_member(chat_id: msj.chat.id, user_id: id_afectada)
                @tg.unban_chat_member(chat_id: msj.chat.id, user_id: id_afectada)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: "Ni nos vimos #{get_username_link(msj.chat.id, id_afectada)}",
                                 reply_to_message: msj.reply_to_message.message_id,
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
        end
    end

    def cumple_requisitos(msj, devolver_miembro = false)
        # Siempre que alguna de estas sea falsa, va a mandar un mensaje de error

        # Chequeo que sea en un grupo
        cumple = validar_grupo(msj.chat.type, msj.chat.id, msj.message_id) &&
                 # Chequeo que esté respondiendo a un mensaje
                 esta_respondiendo(msj) &&
                 # Chequeo que este bot sea admin en ese grupo
                 es_admin(@user.id, msj.chat.id, msj.message_id, 'Necesito ser admin para hacer eso')

        # Chequeo que quien llama al comando sea admin, y que quien se vea afectado por el comando no lo sea
        if devolver_miembro
            if cumple
                return chequear_usuarios(msj, devolver_miembro)
            else
                return false, nil
            end
        else
            return cumple && chequear_usuarios(msj)
        end
    end

    def esta_respondiendo(msj)
        responde = msj.reply_to_message.nil?
        if responde
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que responderle un mensaje a alguien para que este comando funcione',
                             reply_to_message: msj.message_id)
        end
        !responde
    end

    def chequear_usuarios(msj, devolver_miembro = false)
        resultado = false
        miembro = nil

        # Al botazo no le pueden afectar los comandos
        if msj.reply_to_message.from.id == @user.id
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Ni se te ocurra',
                             reply_to_message: msj.message_id)

        # Chequeo que quien llame al comando sea admin
        elsif !es_admin(msj.from.id, msj.chat.id, msj.message_id)
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que ser admin para usar este comando',
                             reply_to_message: msj.message_id)

        # Chequeo si a quien le afecta el comando es admin, y de ser necesario, devuelvo el estatus
        else
            miembro = @tg.get_chat_member(chat_id: msj.chat.id, user_id: msj.reply_to_message.from.id)['result']

            if miembro['status'] == 'administrator' || miembro['status'] == 'creator'
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No podés usar este comando contra un admin',
                                 reply_to_message: msj.message_id)
            else
                resultado = true
               end

        end

        if devolver_miembro
            return resultado, miembro
        else
            return resultado
        end
    end
end
