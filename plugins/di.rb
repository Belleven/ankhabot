class Dankie
    add_handler CommandHandler.new(:di, :di,
                                   'Te repito lo que me digas')
    add_handler CommandHandler.new(:grita, :grita,
                                   'Te grito lo que me digas')


    def di(msg)
        cmd = parse_command(msg)
        text = cmd[:params]
        if (text.nil? || text == '')
            text = "Dale #{TROESMAS.sample}, ¿Qué digo?"
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: text)
            return
        end
        @tg.send_message(chat_id: msg.chat.id, text: text)
    end

    def grita(msg)
        cmd = parse_command(msg)
        text = cmd[:params]
        if (text.nil? || text == '')
            text = "Dale #{TROESMAS.sample}, ¿Qué grito?"
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: text)
            return
        end
        @tg.send_message(chat_id: msg.chat.id, text: text.upcase!)
    end
end
