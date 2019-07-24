class Dankie
    add_handler CommandHandler.new(:rajar, :rajar,
                                   description: 'Echo al usuario que me digas')

    def rajar(msj)
        if cumple_requisitos(msj)
            id_afectada = msj.reply_to_message.from.id
            rol = @tg.get_chat_member(chat_id: msj.chat.id, user_id: id_afectada)['result']['status']

            if rol == 'left' || rol == 'kicked'
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

    def cumple_requisitos(msj)
        validar_grupo(msj.chat.type, msj.chat.id, msj.message_id) &&
            soy_admin(msj) && esta_respondiendo(msj) &&
            chequear_usuarios(msj)
    end

    def soy_admin(msj)
        mi_rol = @tg.get_chat_member(chat_id: msj.chat.id, user_id: @user.id)['result']['status']

        if mi_rol != 'administrator'
            @tg.send_message(chat_id: msj.chat.id, text: 'Necesito ser admin para hacer eso', reply_to_message: msj.message_id)
            return false
        else
            return true
        end
    end

    def esta_respondiendo(msj)
        if msj.reply_to_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que responderle un mensaje a alguien para que este comando funcione',
                             reply_to_message: msj.message_id)
            false
        else
            true
        end
    end

    def chequear_usuarios(msj)
        if es_admin(msj.from.id, msj.chat.id, msj.message_id)
            if msj.reply_to_message.from.id == @user.id
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'Ni se te ocurra',
                                 reply_to_message: msj.message_id)
                false
            elsif es_admin(msj.reply_to_message.from.id, msj.chat.id, msj.message_id)
                @tg.send_message(chat_id: msj.chat.id,
                                 text: 'No podés usar este comando contra un admin',
                                 reply_to_message: msj.message_id)
                false
            else
                true
            end

        else
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Tenés que ser admin para usar este comando',
                             reply_to_message: msj.message_id)
            false
        end
    end
end
