class Dankie
    add_handler Handler::Comando.new(:anuncio, :anuncios, permitir_params: true)
    add_handler Handler::Comando.new(:anunciar, :anuncios, permitir_params: true)

    # Metodo que envia un mensaje a todos los grupos que estuvieron activos
    # y tienen habilitadas la opcion de anuncios
    def anuncios(msj, params)
        return unless validar_desarrollador(msj.from.id, msj.chat.id, msj.message_id)
        return if mensaje_vacío_anuncio(msj, params)

        anunciar(msj.from, msj.chat.id, params)
    end

    def anunciar(usuario_anunciante, chat_id, params)
        # Avisa que se hizo un anuncio
        avisar_canal_comienzo(usuario_anunciante, chat_id)

        regexp_eliminado = /(bot\ is\ not\ a\ member\ of\ the\ (super)?group\ chat)|
                            (bot\ was\ kicked\ from\ the\ (super)?group\ chat)|
                            (bot\ was\ blocked\ by\ the\ user)|
                            (chat\ not\ found)|
                            (PEER_ID_INVALID)|
                            (bot\ is\ not\ a\ member\ of\ the\ channel\ chat)|
                            (bot\ was\ kicked\ from\ the\ channel\ chat)|
                            (group\ chat\ was\ deactivated)|
                            (user\ is\ deactivated)/x

        regexp_no_responder = /(have\ no\ rights\ to\ send\ a\ message)|
                               (have\ no\ write\ access\ to\ the\ chat)|
                               (CHAT_WRITE_FORBIDDEN)|
                               (CHAT_RESTRICTED)|
                               (Too\ Many\ Requests:\ retry\ after)|
                               (need\ administrator\ rights\ in\ the\ channel\ chat)/x

        texto_anuncio = "Hola, soy @#{@user.username} y tengo un anuncio para dar, "\
                        'espero que no sea molesto uwu, pero si lo es, se pueden '\
                        'quitar (de cualquier chat excepto de los canales) con el '\
                        'comando /configuraciones (en la parte de "habilitar '\
                        "anuncios\")\n\n#{params}"

        # Recorro todos los grupos en la db y les envio el mensaje
        %w[channel private group supergroup].each do |tipo|
            @redis.smembers("chat:#{tipo}:activos").each do |chat_id_activo|
                # Me fijo si esta habilitado el anuncio o es un privado
                next if Configuración.config(chat_id_activo, :admite_anuncios) == '0'

                @tg.send_message(
                    chat_id: chat_id_activo.to_i,
                    text: texto_anuncio,
                    disable_notification: true,
                    disable_web_page_preview: true
                )

            # En caso que el id registrado en la base ya no sea vigente, lo elimino
            rescue Telegram::Bot::Exceptions::ResponseError => e
                if regexp_eliminado.match? e.message
                    remover_chat_activo(chat_id_activo, tipo)
                elsif !regexp_no_responder.match? e.message
                    @logger.error("Error anunciando:\n#{e}", al_canal: true)
                end
            end
        end

        @logger.info 'Ya se terminó de anunciar', al_canal: true
    end

    private

    def remover_chat_activo(chat_id, chat_type)
        @redis.srem("chat:#{chat_type}:activos", chat_id)
        @redis.sadd("chat:#{chat_type}:eliminados", chat_id)
    end

    def avisar_canal_comienzo(usuario, chat_id)
        dev = obtener_enlace_usuario(usuario, chat_id)
        @logger.info("El desarrolador #{dev} ha mandado un anunción global.",
                     al_canal: true, parsear_html: false)
    end

    def mensaje_vacío_anuncio(msj, params)
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
