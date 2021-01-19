class Dankie
    add_handler Handler::Comando.new(
        :anuncio,
        :anuncios,
        permitir_params: true
    )

    add_handler Handler::Comando.new(:anunciar, :anuncios, permitir_params: true)

    # Metodo que envia un mensaje a todos los grupos que estuvieron activos
    # y tienen habilitadas la opcion de anuncios
    def anuncios(msj, params)
        return unless validar_desarrollador(msj.from.id, msj.chat.id, msj.message_id)
        return if mensaje_vacío(msj, params)

        anunciar(msj.from, msj.chat.id, params)
    end

    def anunciar(from, chat_id, params)
        # Avisa que se hizo un anuncio
        avisar_canal_comienzo(from, chat_id)

        regexp_eliminado = /(bot\ is\ not\ a\ member\ of\ the\ (super)?group\ chat)|
                            (bot\ was\ kicked\ from\ the\ (super)?group\ chat)|
                            (bot\ was\ blocked\ by\ the\ user)|
                            (chat\ not\ found)|
                            (PEER_ID_INVALID)|
                            (bot\ is\ not\ a\ member\ of\ the\ channel\ chat)|
                            (group\ chat\ was\ deactivated)|
                            (user\ is\ deactivated)/x

        regexp_no_responder = /(have\ no\ rights\ to\ send\ a\ message)|
                               (have\ no\ write\ access\ to\ the\ chat)|
                               (CHAT_WRITE_FORBIDDEN)|
                               (CHAT_RESTRICTED)/x

        # Recorro todos los grupos en la db y les envio el mensaje
        %w[private group supergroup].each do |tipo|
            @redis.smembers("chat:#{tipo}:activos").each do |grupete|
                # Me fijo si esta habilitado el anuncio o es un privado
                next if Configuración.config(grupete, :admite_anuncios) == '0'

                @tg.send_message(chat_id: grupete.to_i, text: params)

            # En caso que el id registrado en la base ya no sea vigente, lo elimino
            rescue Telegram::Bot::Exceptions::ResponseError => e
                if regexp_eliminado.match? e.message
                    remover_grupete(grupete, tipo)
                elsif !regexp_no_responder.match? e.message
                    @logger.error("Error anunciando: #{e}", al_canal: true)
                end
            end
        end

        @logger.info 'Ya se terminó de anunciar', al_canal: true
    end

    private

    def remover_grupete(chat_id, chat_type)
        @redis.srem("chat:#{chat_type}:activos", chat_id)
        @redis.sadd("chat:#{chat_type}:eliminados", chat_id)
    end

    def avisar_canal_comienzo(usuario, chat_id)
        dev = obtener_enlace_usuario(usuario, chat_id)
        @logger.info("El desarrolador #{dev} ha mandado un anunción global.",
                     al_canal: true, parsear_html: false)
    end

    def mensaje_vacío(msj, params)
        if params.nil?
            mensaje_nil = 'Dale papu, tenés que poner algo en el anuncio'
            @tg.send_message(chat_id: msj.chat.id,
                             text: mensaje_nil,
                             reply_to_message_id: msj.message_id)
            return true
        end
        false
    end
end
