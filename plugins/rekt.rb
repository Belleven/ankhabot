class Dankie
    add_handler CommandHandler.new(:rekt, :rekt,
                                   description: 'Informa a un usuario si ha '\
                                                'sido destruido')

    def rekt(msj)
        text = "☐ Not rekt\n"

        3.times { text << REKT.sample + "\n" }

        @tg.send_message(chat_id: msj.chat.id, text: text,
                         reply_to_message_id: msj&.reply_to_message&.message_id)
    end
end
