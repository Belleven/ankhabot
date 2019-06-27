class Dankie
    add_handler CommandHandler.new(:restringir, :restringir,
                                   description: 'Restringe a alguien en el chat '\
                                                'para que no interactúe con el bot '\
                                                '(solo admins)',
                                   allow_params: true)

    add_handler CommandHandler.new(:habilitar, :habilitar,
                                   description: 'Habilita a alguien en el '\
                                                'chat de para que pueda interactuar con el '\
                                                'bot (solo admins)',
                                   allow_params: true)

    add_handler CommandHandler.new(:bloquear, :bloquear, allow_params: true)
    add_handler CommandHandler.new(:desbloquear, :desbloquear, allow_params: true)

    add_handler CommandHandler.new(:bloqueados, :bloqueados)
    add_handler CommandHandler.new(:restringidos, :local_blocked,
                                   description: 'Lista de miembros del chat '\
                                                'bloqueados por el bot')

    def restringir(msg, params)
        comando_lista_negra(msg, :chequeo_local, :bloquear_usuario, msg.chat.id.to_s,
                            params, 'Vos no podés usar esto pa')
    end

    def bloquear(msg, params)
        comando_lista_negra(msg, :validar_desarrollador, :bloquear_usuario, 'globales', params)
    end

    def habilitar(msg, params)
        comando_lista_negra(msg, :es_admin, :desbloquear_usuario,
                            msg.chat.id.to_s, params, 'Vos no podés usar esto pa')
    end

    def desbloquear(msg, params)
        comando_lista_negra(msg, :validar_desarrollador, :desbloquear_usuario, 'globales', params)
    end

    def bloqueados(msg)
        get_blocked(msg, 'globales')
    end

    def local_blocked(msg)
        get_blocked(msg, msg.chat.id.to_s)
    end

    private

    def comando_lista_negra(msg, funcion_validadora, execute_function,
                            block_site, params, text = nil)

        type = msg.chat.type
        chat_id = msg.chat.id
        message_id = msg.message_id
        user_id = msg.from.id

        if params.nil?
            id = nil
        else
            id = natural(params)
            unless id
                @tg.send_message(chat_id: chat_id,
                                 reply_to_message: message_id,
                                 text: 'Pasame un parámetro válido CAPO')
                return
            end
        end

        # Chequeo que sea llamado por quién corresponde y dónde corresponde
        if !validar_grupo(type, chat_id, message_id) ||
           !send(funcion_validadora, user_id, chat_id, message_id, text, id)
            return
        else
            send(execute_function, msg, block_site, id)
            return
        end
    end

    def bloquear_usuario(msg, id_grupo, id = nil)
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
        if (id_grupo != 'globales') && es_admin(id, chat_id, msg.message_id)
            @tg.send_message(chat_id: chat_id, reply_to_message: msg.message_id, text: 'No podés bloquear admines')
            return
        end

        # Chequeo que no esté bloqueado ya
        id = id.to_s

        if @redis.sismember("lista_negra:#{id_grupo}", id)
            @tg.send_message(chat_id: chat_id,
                             reply_to_message: msg.message_id,
                             text: 'Pero cuántas veces te pensás que '\
                                   'podés bloquear a alguien?? ya está en la '\
                                   'lista negra')
        else
            @redis.sadd("lista_negra:#{id_grupo}", id)
            @redis.bgsave

            if msg.reply_to_message.nil?
                if id_grupo == 'globales'
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

    def desbloquear_usuario(msg, id_grupo, id = nil)
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

        if !@redis.sismember("lista_negra:#{id_grupo}", id)
            @tg.send_message(chat_id: chat_id,
                             reply_to_message: msg.message_id,
                             text: 'No puedo desbloquear a alguien que no '\
                                   'está en la lista negra')
        else
            @redis.srem("lista_negra:#{id_grupo}", id)
            @redis.bgsave

            if msg.reply_to_message.nil?

                if id_grupo == 'globales'
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

    def validar_desarrollador(user_id, chat_id, message_id, _text = nil, _id = nil)
        # Chequeo que quien llama al comando sea o desarrollador
        unless DEVS.include?(user_id)
            @tg.send_message(chat_id: chat_id, reply_to_message: message_id,
                             text: 'Vos no podés usar esto pa')
            return false
        end

        true
    end

    def es_admin(user_id, chat_id, message_id, text = nil, _id = nil)
        member = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
        member = Telegram::Bot::Types::ChatMember.new(member['result'])
        status = member.status

        # Chequeo que quien llama al comando sea admin del grupete
        if (status != 'administrator') && (status != 'creator')
            unless text.nil?
                @tg.send_message(chat_id: chat_id, reply_to_message: message_id, text: text)
            end
            return false
        end

        true
    end

    def id_en_grupo(message_id, chat_id, id)
        unless id.nil?

            begin
                # Me fijo que sea una id de un usuario que haya pasado por el chat
                miembro = @tg.get_chat_member(chat_id: chat_id, user_id: id)
                miembro = Telegram::Bot::Types::ChatMember.new(miembro['result'])
            rescue Telegram::Bot::Exceptions::ResponseError => e
                log(Logger::ERROR, e, al_canal: true)
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

    def get_blocked(msg, id_grupo)
        # Solo para ver si anda
        miembros = @redis.smembers("lista_negra:#{id_grupo}")

        if miembros.empty?
            @tg.send_message(chat_id: msg.chat.id, text: 'No hay nadie en la lista negra.')
        else
            mandar_lista_ids(msg.chat.id, miembros, id_grupo == 'globales')
        end
    end

    def mandar_lista_ids(chat_id, lista, es_global)
        inicio = es_global ? "Lista de bloqueados globalmente:\n\n" : "Lista de bloqueados en el grupete:\n\n"
        tamaño = inicio.length
        lineas = [inicio]

        lista.each do |miembro|
            tamaño += 3 + miembro.length

            # Mando blocazos de 4096 caracteres
            if tamaño < 4096
                lineas << '- ' + (es_global ? miembro : get_username_link(chat_id, miembro)) + "\n"
            else
                @tg.send_message(chat_id: chat_id, text: lineas.join(''), parse_mode: 'html', disable_web_page_preview: true, disable_notification: true)
                lineas = ['- ' + miembro + "\n"]
                tamaño = 3 + miembro.length
            end
        end

        # Mando el último cacho
        @tg.send_message(chat_id: chat_id, text: lineas.join(''), parse_mode: 'html', disable_web_page_preview: true, disable_notification: true)
    end
end