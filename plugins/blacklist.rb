class Dankie
    add_handler CommandHandler.new(:ignore, :ignore)
    add_handler CommandHandler.new(:unignore, :unignore)
    add_handler CommandHandler.new(:blocked, :blocked)

    def ignore(msg)
        if msg.chat.type == 'private'
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Esto solo funciona en grupetes')
            return
        elsif msg.chat.type == 'channel'
            return
        end

        chat_id = msg.chat.id
        user_id = msg.from.id

        # Chequeo que quien llama al comando sea o desarrollador, o admin, o creador del grupo
        unless @developers.include?(user_id)
            member = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
            member = Telegram::Bot::Types::ChatMember.new(member['result'])
            status = member.status

            if (status != 'administrator') && (status != 'creator')
                @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Vos no podés usar esto pa')
                return
            end
        end

        # Chequeo casos turbinas de quien va a ser bloqueado
        if msg.reply_to_message

            id = msg.reply_to_message.from.id

            if id == msg.from.id
                @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Cómo te vas a autobloquear papurri??')
                return
            elsif id == @user.id
                @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Ni se te ocurra')
                return
            elsif msg.reply_to_message.from.is_bot
                @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Para qué querés bloquear a un botazo???? Si ni los puedo leer')
                return
            elsif msg.reply_to_message.from.first_name.empty?
                @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Para qué querés bloquear a una cuenta eliminada? Si ya no jode')
                return
            end

        else
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Dale capo a quién ignoro???')
            return
        end

        # Chequeo que no sea desarrollador ni admin del grupete
        if @developers.include?(id)
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'No podés bloquear a un desarrollador pa')
            return
        end

        member_bloq = @tg.get_chat_member(chat_id: chat_id, user_id: id)
        member_bloq = Telegram::Bot::Types::ChatMember.new(member_bloq['result'])
        status = member_bloq.status

        if (status == 'administrator') || (status == 'creator')
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'No se puede bloquear a un admin')
            return
        end

        # Chequeo que no esté bloqueado ya
        id = id.to_s
        if @redis.sismember('bloqueados', id)
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Pero cuántas veces te pensás que podés bloquear a alguien?? ya está en la lista negra')
        else
            @redis.sadd('bloqueados', id)
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.reply_to_message.message_id, text: 'ya no te doy bola papu ¬_¬')
        end
    end

    def unignore(msg)
        if msg.chat.type == 'private'
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Esto solo funciona en grupetes')
            return
        elsif msg.chat.type == 'channel'
            return
        end

        chat_id = msg.chat.id
        user_id = msg.from.id

        # Chequeo que quien llama al comando sea o desarrollador, o admin, o creador del grupo
        unless @developers.include?(user_id)
            member = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
            member = Telegram::Bot::Types::ChatMember.new(member['result'])
            status = member.status

            if (status != 'administrator') && (status != 'creator')
                @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Vos no podés usar esto pa')
                return
            end
        end

        if msg.reply_to_message
            id = msg.reply_to_message.from.id
        else
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Dale capo a quién designoro???')
            return
        end

        id = id.to_s
        if !@redis.sismember('bloqueados', id)
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'No puedo desbloquear a alguien que no está en la lista negra')
        else
            @redis.srem('bloqueados', id)
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.reply_to_message.message_id, text: 'ola de nuevo nwn')
        end
    end

    def save
        # TODO: use @redis
    end

    def blocked(msg)
        # Solo para ver si anda
        miembros = @redis.smembers('bloqueados')

        text = if !miembros.empty?
                   miembros.to_s
               else
                   'No hay nadie en la lista negra.'
               end

        @tg.send_message(chat_id: msg.chat.id, text: text)
    end
end
