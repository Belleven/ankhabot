class Dankie
    add_handler Handler::Mensaje.new(:registrar_chat,
                                     chats_permitidos: %i[group supergroup
                                                          channel private])
    add_handler Handler::EventoDeChat.new(:registrar_chat,
                                          chats_permitidos: %i[group supergroup
                                                               channel private])
    add_handler Handler::Comando.new(:chats, :chats,
                                     descripción: 'Muestro estadísticas de los '\
                                                  'chats en los que estuve')
    add_handler Handler::Comando.new(:estadochat, :estadochat,
                                     permitir_params: true,
                                     descripción: 'Devuelve el estado del chat pasado '\
                                                  'por parámetro')

    add_handler Handler::Comando.new(:testid, :testid,
                                     permitir_params: true)

    def testid(_msj, params)
        @tg.send_message(chat_id: params.to_i,
                         text: 'test id')
    end

    def registrar_chat(msj)
        # Conjuntos con los grupetes
        @redis.sadd("chat:#{msj.chat.type}:activos", msj.chat.id.to_s)
        @redis.srem("chat:#{msj.chat.type}:eliminados", msj.chat.id.to_s)

        if msj.migrate_from_chat_id
            @logger.info("Chat #{msj.migrate_from_chat_id} migró a #{msj.chat.id}",
                         al_canal: true)

            @redis.sadd('chat:group:eliminados', migrate_from_chat_id.to_s)
            @redis.srem('chat:group:activos', migrate_from_chat_id.to_s)

            # Hash con los grupos que migran a supergrupos
            @redis.hset('chats_migrados',
                        msj.migrate_from_chat_id.to_s,
                        msj.chat.id.to_s)
        end
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

        total = activos + eliminados

        texto = "Chats en los que participé: <b>#{total}</b>"
        texto << "\n\nChats en los que estoy: <b>#{activos}</b>"
        texto << "\nChats en los que ya no sigo: <b>#{eliminados}</b>"
        texto << "\n\nGrupos en los que estoy: <b>#{grupo_activos}</b>"
        texto << "\nGrupos en los que ya no sigo: <b>#{grupo_eliminados}</b>"
        texto << "\n\nSupergrupos en los que estoy: <b>#{supergrupo_activos}</b>"
        texto << "\nSupergrupos en los que ya no sigo: <b>#{supergrupo_eliminados}</b>"
        texto << "\n\nCanales en los que estoy: <b>#{canal_activos}</b>"
        texto << "\nCanales en los que ya no sigo: <b>#{canal_eliminados}</b>"
        texto << "\n\nChats privados activos: <b>#{priv_activos}</b>"
        texto << "\nChats privados donde no puedo hablar: <b>#{priv_eliminados}</b>"

        @tg.send_message(chat_id: msj.chat.id,
                         parse_mode: :html,
                         text: texto)
    end

    def estadochat(msj, params)
        unless params
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             text: 'Tenés que pasarme una id de chat')
            nil
        end
    end
end
