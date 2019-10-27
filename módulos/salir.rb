class Dankie
    add_handler Handler::Comando.new(:salir, :salir,
                                     chats_permitidos: %i[group supergroup])

    def salir(msj)
        return unless validar_desarrollador(msj.from.id, msj.chat.id, msj.message_id)

        if msj.reply_to_message.nil? ||
           msj.reply_to_message.from.id != @user.id
            texto_error = 'Si querés que me vaya del grupo, mandá '\
                            'ese comando respondiéndome un mensaje'
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: texto_error)
        else
            begin
                @tg.leave_chat(chat_id: msj.chat.id)
                @logger.info("Me fui de este grupete: #{grupo_del_msj(msj)}")
            rescue Telegram::Bot::Exceptions::ResponseError => e
                case e.to_s
                when /PEER_ID_INVALID/
                    @tg.send_message(chat_id: msj.chat.id,
                                     reply_to_message_id: msj.message_id,
                                     text: 'Hubo algún error y no me pude ir :c')
                end
            end
        end
    end
end
