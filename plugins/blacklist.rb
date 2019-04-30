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
            elsif msg.reply_to_message.from.first_name.empty?
            	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Para qué querés bloquear a una cuenta eliminada? Si ya no jode')
            	return
            end

        else
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Dale capo a quién ignoro???')
            return
        end

        # if id es de un admin
        # putear y return
        if @developers.include?(id)
        	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'No podés bloquear a un desarrollador pa')
        	return
        end

        id = id.to_s
        if @redis.sismember("bloqueados", id)
        	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Pero cuántas veces te pensás que podés bloquear a alguien?? ya está en la lista negra')
        else
        	@redis.sadd("bloqueados", id)
        	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.reply_to_message.message_id, text: 'ya no te doy bola papu ¬_¬')
    	end
    end

    def unignore(msg)
        # if msg.from no es admin
        # putear y return

        if msg.reply_to_message
            id = msg.reply_to_message.from.id
        else
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Dale capo a quién designoro???')
            return
        end

        # if id es de un admin
        # putear y return

        id = id.to_s
        if not @redis.sismember("bloqueados", id)
	       	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'No puedo desbloquear a alguien que no está en la lista negra')
	    else
        	@redis.srem("bloqueados", id)
        	@tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.reply_to_message.message_id, text: 'ola de nuevo nwn')
        end
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
