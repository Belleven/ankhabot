class Dankie

    add_handler CommandHandler.new(:bloqueado, :block,
                                   description: 'Bloquea a alguien en el chat '\
                                                'de interactuar con el bot '\
                                                '(solo admins)',  
                                   allow_params: true)

    add_handler CommandHandler.new(:desbloqueado, :unblock,
                                   description: 'Desbloquea a alguien en el '\
                                                'chat de interactuar con el '\
                                                'bot (solo admins)', 
                                    allow_params: true)

    add_handler CommandHandler.new(:gbloqueado, :gblock,  allow_params: true)
    add_handler CommandHandler.new(:gdesbloqueado, :gunblock,  allow_params: true)

    add_handler CommandHandler.new(:gbloqueados, :blocked)
    add_handler CommandHandler.new(:bloqueados, :local_blocked,
                                   description: 'Lista de miembros del chat '\
                                                'bloqueados por el bot')

    def block(msg, params)
        run_blacklist_command(msg, :chequeo_local, :block_user, msg.chat.id.to_s,
                              params, 'Vos no podés usar esto pa')
    end

    def gblock(msg, params)
        run_blacklist_command(msg, :validate_dev, :block_user, 'globales', params)
    end

    def unblock(msg, params)
        run_blacklist_command(msg, :es_admin, :unblock_user,
                              msg.chat.id.to_s, params, 'Vos no podés usar esto pa')
    end

    def gunblock(msg, params)
        run_blacklist_command(msg, :validate_dev, :unblock_user, 'globales', params)
    end

    def blocked(msg)
        get_blocked(msg, 'globales')
    end

    def local_blocked(msg)
        get_blocked(msg, msg.chat.id.to_s)
    end

    private

    def run_blacklist_command(msg, validate_function, execute_function,
                              block_site, params, text = nil)
       
        type = msg.chat.type
        chat_id = msg.chat.id
        message_id = msg.message_id
        user_id = msg.from.id

        if params.nil?
            id = nil
        else
            id = entero(params)
            if !id
                @tg.send_message(chat_id: chat_id,
                                reply_to_message: message_id,
                                text: 'Pasame un parámetro válido CAPO')
                return
            end
        end

        # Chequeo que sea llamado por quién corresponde y dónde corresponde
        if !validate_group(type, chat_id, message_id) ||
           !send(validate_function, user_id, chat_id, message_id, text, id)
            return
        else
            send(execute_function, msg, block_site, id)
            return
        end
    end

    def block_user(msg, group_id, id = nil)
        
        chat_id = msg.chat.id

        # Chequeo casos turbinas de quien va a ser bloqueado
        if id.nil?
            if msg.reply_to_message

                id = msg.reply_to_message.from.id

                if msg.reply_to_message.from.is_bot
                    @tg.send_message(chat_id: chat_id,
                                     reply_to_message: msg.message_id,
                                     text: 'Para qué querés bloquear a un '\
                                        'botazo???? Si ni los puedo leer')
                    return
                elsif msg.reply_to_message.from.first_name.empty?
                    @tg.send_message(chat_id: chat_id,
                                     reply_to_message: msg.message_id,
                                     text: 'Para qué querés bloquear a una '\
                                        'cuenta eliminada? Si ya no jode')
                    return
                end

            else
                @tg.send_message(chat_id: chat_id,
                                 reply_to_message: msg.message_id,
                                 text: 'Dale capo a quién ignoro???')
                return
            end
        end

        if id == msg.from.id
            @tg.send_message(chat_id: chat_id,
                                reply_to_message: msg.message_id,
                                text: 'Cómo te vas a autobloquear papurri??')
            return
        elsif id == @user.id
            @tg.send_message(chat_id: chat_id,
                                reply_to_message: msg.message_id,
                                text: 'Ni se te ocurra')
            return
        end

        # Chequeo que no sea desarrollador ni admin del grupete
        if DEVS.include?(id)
            @tg.send_message(chat_id: chat_id,
                             reply_to_message: msg.message_id,
                             text: 'No podés bloquear a un desarrollador pa')
            return
        end

        # Si es un bloqueo local chequeo que no se bloquee a un admin
        if (group_id != 'globales') && es_admin(id, chat_id, msg.message_id)
            @tg.send_message(chat_id: chat_id, reply_to_message: msg.message_id, text: "No podés bloquear admines")
            return
        end

        # Chequeo que no esté bloqueado ya
        id = id.to_s

        if @redis.sismember("blacklist:#{group_id}", id)
            @tg.send_message(chat_id: chat_id,
                             reply_to_message: msg.message_id,
                             text: 'Pero cuántas veces te pensás que '\
                                   'podés bloquear a alguien?? ya está en la '\
                                   'lista negra')
        else
            @redis.sadd("blacklist:#{group_id}", id)
            @redis.bgsave
            
            if msg.reply_to_message.nil?
                if group_id == "globales"      
                    @tg.send_message(chat_id: chat_id, text: 'ya no te doy bola ' + id + ' ¬_¬')
                else
                    @tg.send_message(chat_id: chat_id, text: 'ya no te doy bola ' + get_username_link(chat_id, id) + ' ¬_¬',
                                    parse_mode: 'html',
                                    disable_web_page_preview: true,
                                    disable_notification: true)
                end
            else
                @tg.send_message(chat_id: chat_id,
                                reply_to_message: msg.reply_to_message.message_id,
                                text: 'ya no te doy bola ' + get_username_link(chat_id, id) + ' ¬_¬', 
                                parse_mode: 'html',
                                disable_web_page_preview: true,
                                disable_notification: true)
            end
        end
    end

    def unblock_user(msg, group_id, id = nil)
        
        chat_id = msg.chat.id

        if id.nil?
            if msg.reply_to_message
                id = msg.reply_to_message.from.id
            else
                @tg.send_message(chat_id: chat_id,
                                 reply_to_message: msg.message_id,
                                 text: 'Dale capo a quién designoro???')
                return
            end
        end

        if !@redis.sismember("blacklist:#{group_id}", id)
            @tg.send_message(chat_id: chat_id,
                             reply_to_message: msg.message_id,
                             text: 'No puedo desbloquear a alguien que no '\
                                   'está en la lista negra')
        else
            @redis.srem("blacklist:#{group_id}", id)
            @redis.bgsave
            
            if msg.reply_to_message.nil?

                if group_id == "globales"      
                    @tg.send_message(chat_id: chat_id, text: 'ola de nuevo ' + id.to_s + ' nwn')
                else
                    @tg.send_message(chat_id: chat_id, text: 'ola de nuevo ' + get_username_link(chat_id, id) + ' nwn',
                                    parse_mode: 'html',
                                    disable_web_page_preview: true,
                                    disable_notification: true)
                end

            else
                @tg.send_message(chat_id: chat_id,
                                 reply_to_message: msg.reply_to_message.message_id,
                                 text: 'ola de nuevo ' + get_username_link(chat_id, id) + ' nwn', 
                                 parse_mode: 'html',
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
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

    def validate_dev(user_id, chat_id, message_id, _text = nil, id=nil)
        # Chequeo que quien llama al comando sea o desarrollador
        unless DEVS.include?(user_id)
            @tg.send_message(chat_id: chat_id, reply_to_message: message_id,
                             text: 'Vos no podés usar esto pa')
            return false
        end

        true
    end

    def es_admin(user_id, chat_id, message_id, text=nil, id=nil)
        member = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
        member = Telegram::Bot::Types::ChatMember.new(member['result'])
        status = member.status

        # Chequeo que quien llama al comando sea admin del grupete
        if (status != 'administrator') && (status != 'creator')
            if !text.nil?
                @tg.send_message(chat_id: chat_id, reply_to_message: message_id, text: text)
            end
            return false
        end

        true
    end

    def id_en_grupo(message_id, chat_id, id)
        if !id.nil?
         
            begin
                # Me fijo que sea una id de un usuario que haya pasado por el chat
                miembro = @tg.get_chat_member(chat_id: chat_id, user_id: id)
                miembro = Telegram::Bot::Types::ChatMember.new(miembro['result'])
            rescue Telegram::Bot::Exceptions::ResponseError => e
                @logger.error(e)
                @tg.send_message(chat_id: chat_id,
                                reply_to_message: message_id,
                                text: 'No puedo bloquear esa id, pasame una que sea válida de alguien que esté o haya estado alguna vez en el grupete.')
                return false
            end

            if miembro.user.first_name.nil?
                @tg.send_message(chat_id: chat_id,
                                reply_to_message: message_id,
                                text: 'Para qué querés bloquear a una cuenta eliminada? Si ya no jode')
                  return false
            end
        end

        true

    end

    def chequeo_local(user_id, chat_id, message_id, text, id)
        es_admin(user_id, chat_id, message_id, text) && id_en_grupo(message_id, chat_id, id)
    end

    def get_blocked(msg, group_id)
        # Solo para ver si anda
        miembros = @redis.smembers("blacklist:#{group_id}")

        if miembros.empty?
            @tg.send_message(chat_id: msg.chat.id, text: 'No hay nadie en la lista negra.')
        else
            mandar_lista_ids(msg.chat.id, miembros, group_id == "globales")
        end
       
    end

    def mandar_lista_ids(chat_id, lista, es_global)
        
        inicio = if es_global then "Lista de bloqueados globalmente:\n\n" else "Lista de bloqueados en el grupete:\n\n" end
        tamaño = inicio.length
        lineas = [inicio]

        lista.each do |miembro|
            tamaño += 3 + miembro.length
            
            # Mando blocazos de 4096 caracteres            
            if tamaño < 4096
                lineas << "- " + (if es_global then miembro else get_username_link(chat_id, miembro) end) + "\n"
            else
                @tg.send_message(chat_id: chat_id, text: lineas.join(""), parse_mode: 'html', disable_web_page_preview: true, disable_notification: true)
                lineas = ["- " + miembro + "\n"]
                tamaño = 3 + miembro.length
            end          
        
        end

        # Mando el último cacho
        @tg.send_message(chat_id: chat_id, text: lineas.join(""), parse_mode: 'html', disable_web_page_preview: true, disable_notification: true)

    end

    # Esto tranquilamente puede ir en otro lado así lo podemos reusar
    def entero(numero)
        if numero.length < 25
            begin
                num = Integer(numero)
            rescue
                return false
            end

            if num > 0
                return num
            end
        end

        false
    
    end
end
