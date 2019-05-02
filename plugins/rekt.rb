class Dankie
    add_handler CommandHandler.new(:rekt, :rekt, 'Informa a un usuario si ha sido destruido')

    def rekt(msg)
        text = "☐ Not rekt\n"

        3.times { text << REKT.sample + "\n" }

        send_message(chat_id: msg.chat.id, text: text,
                     reply_to_message_id: msg&.reply_to_message&.message_id)
    end
end
