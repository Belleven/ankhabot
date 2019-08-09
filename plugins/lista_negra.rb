class Dankie
    add_handler Handler::Comando.new(:restringir, :restringir,
                                     descripción: 'Restringe a alguien en el chat '\
                                                  'para que no interactúe con el bot '\
                                                  '(solo admins)',
                                     permitir_params: true)

    add_handler Handler::Comando.new(:habilitar, :habilitar,
                                     descripción: 'Habilita a alguien en el '\
                                                  'chat de para que pueda interactuar con el '\
                                                  'bot (solo admins)',
                                     permitir_params: true)

    add_handler Handler::Comando.new(:bloquear, :bloquear, permitir_params: true)
    add_handler Handler::Comando.new(:desbloquear, :desbloquear, permitir_params: true)

    add_handler Handler::Comando.new(:bloqueados, :bloqueados)
    add_handler Handler::Comando.new(:restringidos, :local_blocked,
                                     descripción: 'Lista de miembros del chat '\
                                                  'bloqueados por el bot')

    add_handler Handler::EventoDeChat.new(:lista_negra_supergrupo, tipos: [:migrate_from_chat_id])

    def restringir(msj, params)
        comando_lista_negra(msj, :chequeo_local, :bloquear_usuario, msj.chat.id.to_s,
                            params, 'Vos no podés usar esto pa')
    end

    def bloquear(msj, params)
        comando_lista_negra(msj, :validar_desarrollador, :bloquear_usuario, 'global', params)
    end

    def habilitar(msj, params)
        comando_lista_negra(msj, :es_admin, :desbloquear_usuario,
                            msj.chat.id.to_s, params, 'Vos no podés usar esto pa')
    end

    def desbloquear(msj, params)
        comando_lista_negra(msj, :validar_desarrollador, :desbloquear_usuario, 'global', params)
    end

    def bloqueados(msj)
        obtener_bloqueados(msj, 'global')
    end

    def local_blocked(msj)
        obtener_bloqueados(msj, msj.chat.id.to_s)
    end

    # Para cuando un grupo se convierte en supergrupo
    def lista_negra_supergrupo(msj)
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'lista_negra:')
    end

    private

    def comando_lista_negra(msj, funcion_validadora, execute_function,
                            block_site, params, text = nil)

        tipo = msj.chat.type
        id_chat = msj.chat.id
        id_mensaje = msj.message_id
        id_usuario = msj.from.id

        if params.nil?
            id = nil
        else
            id = natural(params)
            unless id
                @tg.send_message(chat_id: id_chat,
                                 reply_to_message_id: id_mensaje,
                                 text: 'Pasame un parámetro válido CAPO')
                return
            end
        end

        # Chequeo que sea llamado por quién corresponde y dónde corresponde
        if !validar_grupo(tipo, id_chat, id_mensaje) ||
           !send(funcion_validadora, id_usuario, id_chat, id_mensaje, text, id)
            return
        else
            send(execute_function, msj, block_site, id)
            return
        end
    end

    def bloquear_usuario(msj, id_grupo, id = nil)
        id_chat = msj.chat.id

        # Chequeo casos turbinas de quien va a ser bloqueado
        if id.nil?
            if msj.reply_to_message

                id = msj.reply_to_message.from.id

                if id == @user.id
                    @tg.send_message(chat_id: id_chat,
                                     reply_to_message_id: msj.message_id,
                                     text: 'Ni se te ocurra')
                    return

                elsif msj.reply_to_message.from.is_bot
                    @tg.send_message(chat_id: id_chat,
                                     reply_to_message_id: msj.message_id,
                                     text: 'Para qué querés bloquear a un '\
                                        'botazo???? Si ni los puedo leer')
                    return
                elsif msj.reply_to_message.from.first_name.empty?
                    @tg.send_message(chat_id: id_chat,
                                     reply_to_message_id: msj.message_id,
                                     text: 'Para qué querés bloquear a una '\
                                        'cuenta eliminada? Si ya no jode')
                    return
                end

            else
                @tg.send_message(chat_id: id_chat,
                                 reply_to_message_id: msj.message_id,
                                 text: 'Dale capo a quién ignoro???')
                return
            end
        end

        if id == msj.from.id
            @tg.send_message(chat_id: id_chat,
                             reply_to_message_id: msj.message_id,
                             text: 'Cómo te vas a autobloquear papurri??')
            return
        elsif id == @user.id
            @tg.send_message(chat_id: id_chat,
                             reply_to_message_id: msj.message_id,
                             text: 'Ni se te ocurra')
            return
        end

        # Chequeo que no sea desarrollador ni admin del grupete
        if DEVS.include?(id)
            @tg.send_message(chat_id: id_chat,
                             reply_to_message_id: msj.message_id,
                             text: 'No podés bloquear a un desarrollador pa')
            return
        end

        # Si es un bloqueo local chequeo que no se bloquee a un admin
        if (id_grupo != 'global') && es_admin(id, id_chat, msj.message_id)
            @tg.send_message(chat_id: id_chat, reply_to_message_id: msj.message_id, text: 'No podés bloquear admines')
            return
        end

        # Chequeo que no esté bloqueado ya
        id = id.to_s

        if @redis.sismember("lista_negra:#{id_grupo}", id)
            @tg.send_message(chat_id: id_chat,
                             reply_to_message_id: msj.message_id,
                             text: 'Pero cuántas veces te pensás que '\
                                   'podés bloquear a alguien?? ya está en la '\
                                   'lista negra')
        else
            @redis.sadd("lista_negra:#{id_grupo}", id)

            if msj.reply_to_message.nil?
                if id_grupo == 'global'
                    @tg.send_message(chat_id: id_chat, text: 'ya no te doy bola ' + id + ' ¬_¬')
                else
                    @tg.send_message(chat_id: id_chat, text: 'ya no te doy bola ' + obtener_enlace_usuario(id_chat, id) + ' ¬_¬',
                                     parse_mode: 'html',
                                     disable_web_page_preview: true,
                                     disable_notification: true)
                end
            else
                @tg.send_message(chat_id: id_chat,
                                 reply_to_message_id: msj.reply_to_message.message_id,
                                 text: 'ya no te doy bola ' + obtener_enlace_usuario(id_chat, id) + ' ¬_¬',
                                 parse_mode: 'html',
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
        end
    end

    def desbloquear_usuario(msj, id_grupo, id = nil)
        id_chat = msj.chat.id

        if id.nil?
            if msj.reply_to_message
                id = msj.reply_to_message.from.id
            else
                @tg.send_message(chat_id: id_chat,
                                 reply_to_message_id: msj.message_id,
                                 text: 'Dale capo a quién designoro???')
                return
            end
        end

        if !@redis.sismember("lista_negra:#{id_grupo}", id)
            @tg.send_message(chat_id: id_chat,
                             reply_to_message_id: msj.message_id,
                             text: 'No puedo desbloquear a alguien que no '\
                                   'está en la lista negra')
        else
            @redis.srem("lista_negra:#{id_grupo}", id)
            @redis.bgsave

            if msj.reply_to_message.nil?

                if id_grupo == 'global'
                    @tg.send_message(chat_id: id_chat, text: 'ola de nuevo ' + id.to_s + ' nwn')
                else
                    @tg.send_message(chat_id: id_chat, text: 'ola de nuevo ' + obtener_enlace_usuario(id_chat, id) + ' nwn',
                                     parse_mode: 'html',
                                     disable_web_page_preview: true,
                                     disable_notification: true)
                end

            else
                @tg.send_message(chat_id: id_chat,
                                 reply_to_message_id: msj.reply_to_message.message_id,
                                 text: 'ola de nuevo ' + obtener_enlace_usuario(id_chat, id) + ' nwn',
                                 parse_mode: 'html',
                                 disable_web_page_preview: true,
                                 disable_notification: true)
            end
        end
    end

    def id_en_grupo(id_mensaje, id_chat, id)
        unless id.nil?

            begin
                # Me fijo que sea una id de un usuario que haya pasado por el chat
                miembro = @tg.get_chat_member(chat_id: id_chat, user_id: id)
                miembro = Telegram::Bot::Types::ChatMember.new(miembro['result'])
            rescue Telegram::Bot::Exceptions::ResponseError => e
                @logger.log(Logger::ERROR, e, al_canal: true)
                @tg.send_message(chat_id: id_chat,
                                 reply_to_message_id: id_mensaje,
                                 text: 'No puedo bloquear esa id, pasame una que sea válida de alguien que esté o haya estado alguna vez en el grupete.')
                return false
            end

            if miembro.user.first_name.nil?
                @tg.send_message(chat_id: id_chat,
                                 reply_to_message_id: id_mensaje,
                                 text: 'Para qué querés bloquear a una cuenta eliminada? Si ya no jode')
                return false
            end
        end

        true
    end

    def chequeo_local(id_usuario, id_chat, id_mensaje, text, id)
        es_admin(id_usuario, id_chat, id_mensaje, text) &&
            id_en_grupo(id_mensaje, id_chat, id)
    end

    def obtener_bloqueados(msj, id_grupo)
        usuario_id = msj.from.id
        id_chat = msj.chat.id
        id_mensaje = msj.message_id

        es_global = id_grupo == 'global'
        error_admin = 'Solo los admins pueden usar esto'
        miembros = @redis.smembers("lista_negra:#{id_grupo}")

        if (es_global && validar_desarrollador(usuario_id, id_chat, id_mensaje)) ||
           (!es_global && es_admin(usuario_id, id_chat, id_mensaje, error_admin))

            if miembros.empty?
                extra = es_global ? '.' : ' del grupete.'
                @tg.send_message(chat_id: id_chat,
                                 text: 'No hay nadie en la lista negra' + extra,
                                 reply_to_message_id: id_mensaje)
            else
                mandar_lista_ids(id_chat, miembros, es_global)
            end
        end
    end

    def mandar_lista_ids(id_chat, lista, es_global)
        inicio = es_global ? "Lista de bloqueados globalmente:\n\n" : "Lista de bloqueados en el grupete:\n\n"
        tamaño = inicio.length
        lineas = [inicio]

        lista.each do |miembro|
            tamaño += 3 + miembro.length

            # Mando blocazos de 4096 caracteres
            if tamaño < 4096
                lineas << '- ' + (es_global ? miembro : obtener_enlace_usuario(id_chat, miembro)) + "\n"
            else
                @tg.send_message(chat_id: id_chat,
                                 text: lineas.join(''),
                                 parse_mode: :html,
                                 disable_web_page_preview: true,
                                 disable_notification: true)
                lineas = ['- ' + miembro + "\n"]
                tamaño = 3 + miembro.length
            end
        end

        # Mando el último cacho
        @tg.send_message(chat_id: id_chat,
                         text: lineas.join(''),
                         parse_mode: :html,
                         disable_web_page_preview: true,
                         disable_notification: true)
    end
end
