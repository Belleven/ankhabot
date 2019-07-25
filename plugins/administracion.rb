class Dankie
    add_handler Handler::Comando.new(:rajar, :rajar,
                                     description: 'Echo al usuario que me digas')
    add_handler Handler::Comando.new(:kick, :rajar,
                                     description: 'Echo al usuario que me digas')
    add_handler Handler::Comando.new(:ban, :ban,
                                     description: 'Baneo al usuario que me digas')
    add_handler Handler::Comando.new(:nisban, :ban,
                                     description: 'Baneo al usuario que me digas')

    def rajar(msj)
        cumple, miembro = cumple_requisitos(msj)

        if cumple
            id_afectada = msj.reply_to_message.from.id

            if miembro['status'] == 'left' || miembro['status'] == 'kicked' ||
               (miembro['status'] == 'restricted' && miembro['is_member'])

                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No voy a echar a alguien que no está en el grupo',
                                 reply_to_message_id: msj.message_id)
            else

                @tg.kick_chat_member(chat_id: msj.chat.id, user_id: id_afectada)
                @tg.unban_chat_member(chat_id: msj.chat.id, user_id: id_afectada)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: "Ni nos vimos #{get_username_link(msj.chat.id, id_afectada)}",
                                 reply_to_message_id: msj.reply_to_message.message_id,
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
        end
    end

    def ban(msj)
        cumple, miembro = cumple_requisitos(msj)

        if cumple
            id_afectada = msj.reply_to_message.from.id

            if miembro['status'] == 'kicked'
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No puedo a banear a alguien que ya está baneado',
                                 reply_to_message_id: msj.message_id)
            else
                @tg.kick_chat_member(chat_id: msj.chat.id, user_id: id_afectada)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: "Pero mirá el ban que te comiste #{get_username_link(msj.chat.id, id_afectada)}",
                                 reply_to_message_id: msj.reply_to_message.message_id,
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
        end
    end

    def cumple_requisitos(msj)
        # Siempre que alguna de estas sea falsa, va a mandar un mensaje de error

        # Chequeo que sea en un grupo
        validar_grupo(msj.chat.type, msj.chat.id, msj.message_id) &&
            # Chequeo que esté respondiendo a un mensaje
            esta_respondiendo(msj) &&
            # Chequeo que este bot sea admin en ese grupo y tenga los permisos correspondientes
            tengo_permisos(msj) &&
            # Chequeo que el usuario que llamó al comando sea admin y que quien se vea afectado no
            # Además devuelve el chat_member del usuario afectado (en caso de que pase las validaciones)
            # Devuelve una tupla (bool, chat_member), no se bien como funciona pero acá compara el bool con
            # los anteriores, y además devuelve el chat_member sin romperse.
            chequear_usuarios(msj)
    end

    def tengo_permisos(msj)
        yo = @tg.get_chat_member(chat_id: msj.chat.id, user_id: @user.id)['result']

        permisos = false

        if yo['status'] != 'administrator'
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Necesito ser admin para hacer eso',
                             reply_to_message_id: msj.message_id)
        elsif !yo['can_restrict_members']
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'No tengo permisos para restringir/suspender usuarios',
                             reply_to_message_id: msj.message_id)
        else
            permisos = true
        end

        permisos
    end

    def esta_respondiendo(msj)
        responde = msj.reply_to_message.nil?
        if responde
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que responderle un mensaje a alguien para que este comando funcione',
                             reply_to_message_id: msj.message_id)
        end
        !responde
    end

    def chequear_usuarios(msj)
        resultado = false
        miembro = nil

        # Al botazo no le pueden afectar los comandos
        if msj.reply_to_message.from.id == @user.id
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Ni se te ocurra',
                             reply_to_message_id: msj.message_id)

        # Chequeo que quien llame al comando sea admin
        elsif !es_admin(msj.from.id, msj.chat.id, msj.message_id)
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que ser admin para usar este comando',
                             reply_to_message_id: msj.message_id)

        # Chequeo si a quien le afecta el comando es admin, y de ser necesario, devuelvo el estatus
        else
            miembro = @tg.get_chat_member(chat_id: msj.chat.id, user_id: msj.reply_to_message.from.id)['result']

            if miembro['status'] == 'administrator' || miembro['status'] == 'creator'
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No podés usar este comando contra un admin',
                                 reply_to_message_id: msj.message_id)
            else
                resultado = true
               end

        end

        [resultado, miembro]
    end
end
