class Dankie
    add_handler Handler::Mensaje.new(
        :registrar_chat,
        chats_permitidos: %i[group supergroup channel private]
    )

    add_handler Handler::EventoDeChat.new(
        :registrar_chat,
        chats_permitidos: %i[group supergroup channel private]
    )

    add_handler Handler::Comando.new(
        :chats,
        :chats,
        descripción: 'Muestro estadísticas de los chats en los que estuve'
    )

    add_handler Handler::Comando.new(
        :estadochat,
        :estadochat,
        permitir_params: true,
        descripción: 'Devuelve el estado del chat pasado por parámetro'
    )

    def registrar_chat(msj)
        # Conjuntos con los grupetes
        @redis.sadd("chat:#{msj.chat.type}:activos", msj.chat.id.to_s)
        @redis.srem("chat:#{msj.chat.type}:eliminados", msj.chat.id.to_s)

        return unless msj.migrate_from_chat_id

        @logger.info("Chat #{msj.migrate_from_chat_id} migró a #{msj.chat.id}",
                     al_canal: true)

        @redis.sadd('chat:group:eliminados', msj.migrate_from_chat_id.to_s)
        @redis.srem('chat:group:activos', msj.migrate_from_chat_id.to_s)

        # Hash con los grupos que migran a supergrupos
        @redis.hset('chats_migrados',
                    msj.migrate_from_chat_id.to_s,
                    msj.chat.id.to_s)
    end

    def chats(msj)
        priv_activos = @redis.scard('chat:private:activos')
        priv_eliminados = @redis.scard('chat:private:eliminados')

        canal_activos = @redis.scard('chat:channel:activos')
        canal_eliminados = @redis.scard('chat:channel:eliminados')

        grupo_activos = @redis.scard('chat:group:activos')
        grupo_eliminados = @redis.scard('chat:group:eliminados')

        supergrupo_activos = @redis.scard('chat:supergroup:activos')
        supergrupo_eliminados = @redis.scard('chat:supergroup:eliminados')

        activos = priv_activos + canal_activos +
                  grupo_activos + supergrupo_activos

        eliminados = priv_eliminados + canal_eliminados +
                     grupo_eliminados + supergrupo_eliminados

        texto = "Chats en los que participé: <b>#{activos + eliminados}</b>"\
                "\n\nChats en los que estoy: <b>#{activos}</b>"\
                "\nChats en los que ya no sigo: <b>#{eliminados}</b>"\
                "\n\nGrupos en los que estoy: <b>#{grupo_activos}</b>"\
                "\nGrupos en los que ya no sigo: <b>#{grupo_eliminados}</b>"\
                "\n\nSupergrupos en los que estoy: <b>#{supergrupo_activos}</b>"\
                "\nSupergrupos en los que ya no sigo: <b>#{supergrupo_eliminados}</b>"\
                "\n\nCanales en los que estoy: <b>#{canal_activos}</b>"\
                "\nCanales en los que ya no sigo: <b>#{canal_eliminados}</b>"\
                "\n\nChats privados activos: <b>#{priv_activos}</b>"\
                "\nChats privados donde no puedo hablar: <b>#{priv_eliminados}</b>"

        @tg.send_message(
            chat_id: msj.chat.id,
            parse_mode: :html,
            text: texto
        )
    end

    def estadochat(msj, params)
        return unless validar_desarrollador(msj.from.id, msj.chat.id, msj.message_id)
        return if params_inválidos_estado_chat(msj, params)

        # Mando mensaje de prueba para saber si sigo en el chat
        begin
            id_chat = params.to_i
            mensaje = @tg.send_message(
                chat_id: id_chat,
                text: 'Mensaje para ver si sigo en el grupo'
            )
        rescue Telegram::Bot::Exceptions::ResponseError => e
            analizar_excepción_estado_chat(msj, e)
            return
        end

        # Si no me aparece como que se mandó correctamente entonces no puedo decidir
        unless mensaje && mensaje['ok']
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'El mensaje de prueba que mandé, me llegó con errores así que '\
                      'no puedo saber si sigo en ese chat',
                reply_to_message_id: msj.message_id
            )
            return
        end

        # Borro el mensaje mandado para evitar el spam
        begin
            @tg.delete_message(
                chat_id: id_chat,
                message_id: mensaje.dig('result', 'message_id').to_i
            )
        rescue Telegram::Bot::Exceptions::ResponseError => e
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'Salto un error tratando de borrar el mensaje de prueba '\
                      'así que probablemente haya podido mandarlo y siga en ese chat.'\
                      "\nError: #{e.message}",
                reply_to_message_id: msj.message_id
            )
            return
        end

        # Aviso que sigo en ese chat
        @tg.send_message(
            chat_id: msj.chat.id,
            text: 'Sigo estando en ese chat',
            reply_to_message_id: msj.message_id
        )
    end

    private

    def params_inválidos_estado_chat(msj, params)
        if params.nil? || !/\A-?\d+\z/.match?(params)
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Tenés que pasarme una id de chat válida'
            )
            return true
        elsif (migrado = @redis.hget('chats_migrados', params))
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "Ese chat migró a #{migrado}"
            )
            return true
        end
        false
    end

    def analizar_excepción_estado_chat(msj, exc)
        texto = case exc.message
                when /chat not found/
                    "\nNunca estuve en este chat, o no existe"
                when /bot was kicked from the ((super)?group|channel) chat/
                    "\nMe banearon en ese chat"
                when /bot is not a member of the ((super)?group|channel) chat/
                    "\nNo estoy en ese chat"
                when /PEER_ID_INVALID/
                    "\nEse usuario me tiene bloqueado o nunca iniciamos conversación"
                when /bot can't send messages to bots/
                    "\nEse usuario es un bot, no le puedo hablar"
                when /user is deactivated/
                    "\nEse usuario es una cuenta eliminada"
                else
                    analizar_excepción_extraña_estado_chat(exc)
                end

        @tg.send_message(
            chat_id: msj.chat.id,
            text: texto,
            reply_to_message_id: msj.message_id
        )
    end

    def analizar_excepción_extraña_estado_chat(exc)
        case exc.message
        when /have no rights to send a message/, /CHAT_RESTRICTED/,
             /have no write access to the chat/, /CHAT_WRITE_FORBIDDEN/
            "\nEstoy en ese chat pero no tengo permisos para mandar mensajes"
        when /group chat was deactivated/
            "\nEl grupo fue eliminado"
        when /Too Many Requests: retry after/
            "\nEstoy en el grupo pero tiene slow mode, no puedo mandar mensajes"
        when /need administrator rights in the channel chat/
            "\nEstoy en el canal pero no puedo mandar mensajes"
        else
            "\nSaltó este otro error y no puedo saber si "\
            "estoy en el chat: #{exc}"
        end
    end
end
