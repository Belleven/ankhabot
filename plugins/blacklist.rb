class Dankie
    add_handler CommandHandler.new(:ignore, :ignore)
    add_handler CommandHandler.new(:unignore, :unignore)

    def ignore(msg)
        # if msg.from no es admin
        # putear y return

        if msg.reply_to_message
            id = msg.reply_to_message.from.id
        else
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: 'Dale capo a quien ignoro')
            return
        end

        # if id es de un admin
        # putear y return

        @blacklist_arr.push(id)
        @tg.send_message(chat_id: msg.chat.id,
                         reply_to_message: msg.reply_to_message.message_id,
                         text: 'ya no te doy bola papu ¬_¬')
    end

    def unignore(msg)
        # if msg.from no es admin
        # putear y return

        if msg.reply_to_message
            id = msg.reply_to_message.from.id
        else
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: 'Dale capo a quien designoro')
            return
        end

        # if id es de un admin
        # putear y return

        @blacklist_arr.delete(id)
        @tg.send_message(chat_id: msg.chat.id,
                         reply_to_message: msg.reply_to_message.message_id,
                         text: 'ola de nuevo nwn')
    end

    def save
        # TODO: use @redis
    end

    def populate_blacklist
        # TODO: read redis and populate dankie array
        # TODO: learn redis
        @blacklist_populated = true
    end
end
