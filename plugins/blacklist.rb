class Dankie
    add_handler CommandHandler.new(:ignore, :ignore)
    add_handler CommandHandler.new(:unignore, :unignore)
    add_handler CommandHandler.new(:blocked, :blocked)

    def ignore(msg)
        # if msg.from no es admin
        # putear y return

        if msg.reply_to_message
            
            id = msg.reply_to_message.from.id
            
            if id == msg.from.id
            	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Cómo te vas a autobloquear papurri??')
            	return
            elsif id == @user.id
            	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Ni se te ocurra')
            	return
            end

        else
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Dale capo a quién ignoro???')
            return
        end

        # if id es de un admin
        # putear y return
        if id == 267832653
        	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Pará capo que estoy testeando no te hagás el poronga')
        	return
        end

        @redis.sadd("bloqueados", id.to_s)
        @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.reply_to_message.message_id, text: 'ya no te doy bola papu ¬_¬')
    end

    def unignore(msg)
        # if msg.from no es admin
        # putear y return

        if msg.reply_to_message
            id = msg.reply_to_message.from.id
        else
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: 'Dale capo a quién designoro???')
            return
        end

        # if id es de un admin
        # putear y return

        @redis.srem("bloqueados", id.to_s)
        @tg.send_message(chat_id: msg.chat.id,
                         reply_to_message: msg.reply_to_message.message_id,
                         text: 'ola de nuevo nwn')
    end

    def save
        # TODO: use @redis
    end

    def blocked(msg)
    	# Solo para ver si anda
        miembros = @redis.smembers("bloqueados")
        
        if not miembros.empty?
        	text = miembros.to_s
        else
        	text = "No hay nadie en la lista negra."
        end

        @tg.send_message(chat_id: msg.chat.id, text: text)
    end
end
