class Dankie
    add_handler CommandHandler.new(:salir, :salir)

    def salir(msj)
        if validar_desarrollador(msj.from.id, msj.chat.id, msj.message_id) && validar_grupo(msj.chat.type, msj.chat.id, msj.message_id)
            if msj.reply_to_message.nil? || msj.reply_to_message.from.id != @user.id
                texto_error = 'Si querés que me vaya del grupo, mandá ese comando respondiéndome un mensaje'
                @tg.send_message(chat_id: msj.chat.id, reply_to_message: msj.message_id, text: texto_error)
            else
                @tg.leave_chat(chat_id: msj.chat.id)
            end
        end
    end
end
