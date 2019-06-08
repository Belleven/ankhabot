class Dankie
    add_handler CommandHandler.new(:bloqueado, :block,
                                   description: 'Bloquea a alguien en el chat '\
                                                'de interactuar con el bot '\
                                                '(solo admins)')
    add_handler CommandHandler.new(:desbloqueado, :unblock,
                                   description: 'Desbloquea a alguien en el '\
                                                'chat de interactuar con el '\
                                                'bot (solo admins)')

    add_handler CommandHandler.new(:gbloqueado, :gblock)
    add_handler CommandHandler.new(:gdesbloqueado, :gunblock)

    add_handler CommandHandler.new(:gbloqueados, :blocked)
    add_handler CommandHandler.new(:bloqueados, :local_blocked,
                                   description: 'Lista de miembros del chat '\
                                                'bloqueados del bot')

    def block(msg)
        run_blacklist_command(msg, :check_admin, :block_user, msg.chat.id.to_s,
                              'Vos no podés usar esto pa')
    end

    def gblock(msg)
        run_blacklist_command(msg, :validate_dev, :block_user, 'globales')
    end

    def unblock(msg)
        run_blacklist_command(msg, :check_admin, :unblock_user,
                              msg.chat.id.to_s, 'Vos no podés usar esto pa')
    end

    def gunblock(msg)
        run_blacklist_command(msg, :validate_dev, :unblock_user, 'globales')
    end

    def blocked(msg)
        get_blocked(msg, 'global')
    end

    def local_blocked(msg)
        get_blocked(msg, msg.chat.id.to_s)
    end

    private

    def run_blacklist_command(msg, validate_function, execute_function,
                              block_site, text = nil)
        type = msg.chat.type
        chat_id = msg.chat.id
        message_id = msg.message_id
        user_id = msg.from.id

        # Chequeo que sea llamado por quién corresponde y dónde corresponde
        if !validate_group(type, chat_id, message_id) ||
           !send(validate_function, user_id, chat_id, message_id, text)
            return
        else
            #           id =
            #           if HAY PARÁMETROS
            #                if parametros.length != 1 || !(id = entero(parametros[0]))
            #                    if = true
            #                else
            #                    # Me fijo que sea una id de un usuario que haya pasado por el chat
            #                    @tg.get_chat_member(chat_id: chat_id, user_id: id)
            #                    rescue Telegram::Bot::Exceptions::TelegramError => e
            #                        @logger.error(e)
            #                    ensure
            #                        @tg.send_message(chat_id: msg.chat.id,
            #                                        reply_to_message: msg.message_id,
            #                                        text: 'No puedo bloquear esa id, pasame una que sea válida')
            #                        return
            #                    end
            #                end

            send(execute_function, msg, block_site)
            return
            #            end
        end
    end

    def block_user(msg, group_id, id = nil)
        # Chequeo casos turbinas de quien va a ser bloqueado
        if id.nil?
            if msg.reply_to_message

                id = msg.reply_to_message.from.id

                if id == msg.from.id
                    @tg.send_message(chat_id: msg.chat.id,
                                     reply_to_message: msg.message_id,
                                     text: 'Cómo te vas a autobloquear papurri??')
                    return
                elsif id == @user.id
                    @tg.send_message(chat_id: msg.chat.id,
                                     reply_to_message: msg.message_id,
                                     text: 'Ni se te ocurra')
                    return
                elsif msg.reply_to_message.from.is_bot
                    @tg.send_message(chat_id: msg.chat.id,
                                     reply_to_message: msg.message_id,
                                     text: 'Para qué querés bloquear a un '\
                                        'botazo???? Si ni los puedo leer')
                    return
                elsif msg.reply_to_message.from.first_name.empty?
                    @tg.send_message(chat_id: msg.chat.id,
                                     reply_to_message: msg.message_id,
                                     text: 'Para qué querés bloquear a una '\
                                        'cuenta eliminada? Si ya no jode')
                    return
                end

            else
                @tg.send_message(chat_id: msg.chat.id,
                                 reply_to_message: msg.message_id,
                                 text: 'Dale capo a quién ignoro???')
                return
            end
        end

        # Chequeo que no sea desarrollador ni admin del grupete
        if DEVS.include?(id)
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: 'No podés bloquear a un desarrollador pa')
            return
        end

        # Si es un bloqueo local chequeo que no se bloquee a un admin
        if (group_id != 'global') &&
           check_admin(user_id: id, chat_id: msg.chat.id,
                       message_id: msg.message_id,
                       text: 'No podés bloquear a un admin')
            return
        end

        # Chequeo que no esté bloqueado ya
        id = id.to_s

        if @redis.sismember("blacklist:#{group_id}", id)
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: 'Pero cuántas veces te pensás que '\
                                   'podés bloquear a alguien?? ya está en la '\
                                   'lista negra')
        else
            @redis.sadd("blacklist:#{group_id}", id)
            @redis.bgsave
            @tg.send_message(chat_id: msg.chat.id,
                             eply_to_message: msg.reply_to_message.message_id,
                             text: 'ya no te doy bola papu ¬_¬')
        end
    end

    def unblock_user(msg, group_id, id = nil)
        if id.nil?
            if msg.reply_to_message
                id = msg.reply_to_message.from.id
            else
                @tg.send_message(chat_id: msg.chat.id,
                                 reply_to_message: msg.message_id,
                                 text: 'Dale capo a quién designoro???')
                return
            end
        end

        if !@redis.sismember("blacklist:#{group_id}", id)
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: 'No puedo desbloquear a alguien que no '\
                                   'está en la lista negra')
        else
            @redis.srem("blacklist:#{group_id}", id)
            @redis.bgsave
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.reply_to_message.message_id,
                             text: 'ola de nuevo nwn')
        end
    end

    def validate_group(type, chat_id, message_id)
        if type == 'private'
            @tg.send_message(chat_id: chat_id, reply_to_message: message_id,
                             text: 'Esto solo funciona en grupetes')
            return false
        end

        true
    end

    def validate_dev(user_id, chat_id, message_id, _text = nil)
        # Chequeo que quien llama al comando sea o desarrollador
        unless DEVS.include?(user_id)
            @tg.send_message(chat_id: chat_id, reply_to_message: message_id,
                             text: 'Vos no podés usar esto pa')
            return false
        end

        true
    end

    def check_admin(user_id, chat_id, message_id, text)
        member = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
        member = Telegram::Bot::Types::ChatMember.new(member['result'])
        status = member.status

        # Chequeo que quien llama al comando sea admin del grupete
        if (status != 'administrator') && (status != 'creator')
            @tg.send_message(chat_id: chat_id, reply_to_message: message_id,
                             text: text)
            return false
        end

        true
    end

    def get_blocked(msg, group_id)
        # Solo para ver si anda
        miembros = @redis.smembers("blacklist:#{group_id}")

        text = if !miembros.empty?
                   miembros.to_s
               else
                   'No hay nadie en la lista negra.'
               end

        @tg.send_message(chat_id: msg.chat.id, text: text)
    end

    # Esto tranquilamente puede ir en otro lado así lo podemos reusar
    def entero(numero)
        #    return Integer(numero)
        # rescue
        #    return false
        # end
    end
end
