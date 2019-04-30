class Dankie
    add_handler CommandHandler.new(:block, :block)
    add_handler CommandHandler.new(:unblock, :unblock)
    add_handler CommandHandler.new(:gblock, :gblock)
    add_handler CommandHandler.new(:gunblock, :gunblock)

    add_handler CommandHandler.new(:blocked, :blocked)
    add_handler CommandHandler.new(:localblocked, :local_blocked)

    def block(msg)
        run_command(msg, :check_admin, :block_user, msg.chat.id.to_s, "Vos no podés usar esto pa")
    end

    def gblock(msg)      
        run_command(msg, :validate_dev, :block_user, "globales")
    end

    def unblock(msg)
        run_command(msg, :check_admin, :unblock_user, msg.chat.id.to_s, "Vos no podés usar esto pa")
    end

    def gunblock(msg)
        run_command(msg, :validate_dev, :unblock_user, "globales")
    end

    private
    def run_command(msg, validate_function, execute_function, block_site, text=nil)
        type = msg.chat.type
        chat_id = msg.chat.id
        message_id = msg.message_id
        user_id = msg.from.id

        if not validate_group(type, chat_id, message_id) or not send(validate_function, user_id, chat_id, message_id, text)
           return
        else
            send(execute_function, msg, block_site)
            return
        end
    end

    private
    def block_user(msg, block_site)
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
        if DEVS.include?(id)
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'No podés bloquear a un desarrollador pa')
            return
        end

        # Si es un bloqueo local chequeo que no se bloquee a un admin
        if block_site != "globales" and check_admin(user_id: id, chat_id: msg.chat.id, message_id: msg.message_id, text: "No podés bloquear a un admin")
            return
        end

        # Chequeo que no esté bloqueado ya
        id = id.to_s
        block_site = "bloqueados:" + block_site
        
        if @redis.sismember(block_site, id)
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Pero cuántas veces te pensás que podés bloquear a alguien?? ya está en la lista negra')
        else
            @redis.sadd(block_site, id)
            @redis.bgsave()
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.reply_to_message.message_id, text: 'ya no te doy bola papu ¬_¬')
        end

    end

    private
    def unblock_user(msg, block_site)
        if msg.reply_to_message
            id = msg.reply_to_message.from.id
        else
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'Dale capo a quién designoro???')
            return
        end

        id = id.to_s
        block_site = "bloqueados:" + block_site

        if !@redis.sismember(block_site, id)
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.message_id, text: 'No puedo desbloquear a alguien que no está en la lista negra')
        else
            @redis.srem(block_site, id)
            @redis.bgsave()
            @tg.send_message(chat_id: msg.chat.id, reply_to_message: msg.reply_to_message.message_id, text: 'ola de nuevo nwn')
        end

    end


    private
    def validate_group(type, chat_id, message_id)
    	if type == 'private'
            @tg.send_message(chat_id: chat_id, reply_to_message: message_id, text: 'Esto solo funciona en grupetes')
            return false
        elsif type == 'channel'
            return false
        end

        return true
    end

    private
    def validate_dev(user_id, chat_id, message_id, text=nil)
        # Chequeo que quien llama al comando sea o desarrollador
        unless DEVS.include?(user_id)
            @tg.send_message(chat_id: chat_id, reply_to_message: message_id, text: 'Vos no podés usar esto pa')
            return false
        end

        return true
    end


    private
    def check_admin(user_id, chat_id, message_id, text)
        member = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
        member = Telegram::Bot::Types::ChatMember.new(member['result'])
        status = member.status

        # Chequeo que quien llama al comando sea admin del grupete
        if (status != 'administrator') && (status != 'creator')
            @tg.send_message(chat_id: chat_id, reply_to_message: message_id, text: text)
            return false
        else 
            return true
        end

    end


    def blocked(msg)
        get_blocked(msg, "globales")
    end

    def local_blocked(msg)
        get_blocked(msg, msg.chat.id.to_s)
    end

    private
    def get_blocked(msg, block_site)
        # Solo para ver si anda
        miembros = @redis.smembers('bloqueados:' + block_site)

        text = if !miembros.empty?
                   miembros.to_s
               else
                   'No hay nadie en la lista negra.'
               end

        @tg.send_message(chat_id: msg.chat.id, text: text)
    end

end