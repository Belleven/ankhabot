class Dankie
    add_handler Handler::Comando.new(
        :anuncios,
        :anuncios,
        permitir_params: true,
        descripción: 'Anuncios para hacer (solo devs)'
    )

    # Metodo que envia un mensaje a todos los grupos que estuvieron activos
    # y tienen habilitadas la opcion de anuncios
    def anuncios(msj, params)
        return unless validar_desarrollador(msj.from.id, msj.chat.id,
                                            msj.message_id)
        return if mensaje_vacío(msj, params)

        # Avisa que se hizo un anuncio
        avisar_canal(msj.from.id, msj.chat.id)

        # Recorro todos los grupos en la db y les envio el mensaje
        %w[private group supergroup].each do |tipo|
            @redis.smembers("chat:#{tipo}:activos").each do |grupete|
                # Me fijo si esta habilitado el anuncio o es un privado
                if (@redis.hget("configs:#{grupete}",
                                'admite_anuncios').to_i == 1) || (tipo == 'private')
                    @tg.send_message(chat_id: grupete.to_i,
                                     text: params)
                end

            # En caso que el id registrado en la base ya no sea vigente, lo elimino
            rescue Telegram::Bot::Exceptions::ResponseError => e
                no_es_miembro  = / bot is not a member of the/
                fue_kickeado   = / bot was kicked from/
                fue_bloqueado  = /  PEER_ID_INVALID /
                if /#{no_es_miembro} | #{fue_kickeado} | #{fue_bloqueado}/x =~ e.message
                    remover_grupete(grupete, tipo)
                end
            end
        end
    end

    def remover_grupete(chat_id, chat_type)
        @redis.srem("chat:#{chat_type}:activos", chat_id)
        @redis.sadd("chat:#{chat_type}:eliminados", chat_id)
    end

    def avisar_canal(id, chat_id)
        dev = obtener_enlace_usuario(id, chat_id)
        @logger.info("El desarrolador #{dev} ha mandado un anunción global.",
                     al_canal: true, parsear_html: false)
    end

    def mensaje_vacío(msj, params)
        if params.nil?
            mensaje_nil = 'Dale papu, ténes que poner algo en el anuncio'
            @tg.send_message(chat_id: msj.chat.id,
                             text: mensaje_nil,
                             reply_to_message_id: msj.message_id)
            return true
        end
        false
    end
end
