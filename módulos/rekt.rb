class Dankie
    add_handler Handler::Comando.new(:rekt, :rekt,
                                     descripción: 'Informo a un usuario si ha '\
                                                  'sido destruido')

    def rekt(msj)
        texto = "☐ Not rekt\n"

        3.times { texto << "#{REKT.sample}\n" }

        @tg.send_message(chat_id: msj.chat.id,
                         text: texto,
                         reply_to_message_id: msj&.reply_to_message&.message_id)
    end
end
