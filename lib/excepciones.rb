class ManejoExcepciones
    def initialize(logger)
        @logger = logger
    end

    def loggear(excepción, args)
        manejar(excepción, args)
    end

    def capturar(excepción)
        manejar(excepción, nil)
    end

    private

    def manejar(excepción, args)
        return false unless excepción.respond_to?(:error_code) &&
                            excepción.respond_to?(:message)
        unless excepción.instance_of?(Telegram::Bot::Exceptions::ResponseError)
            return false
        end

        método = "manejar_error_#{excepción.error_code}".to_sym
        chat = args && args[:chat_id] ? "en #{args[:chat_id]}" : '(F en el chat)'

        return send(método, excepción.message, chat, args) if respond_to?(método, true)

        if args && args[:chat_id]
            @logger.warn('chat_id que causa la siguiente excepción '\
                         "desconocida: #{args[:chat_id]}", al_canal: true)
        end

        false
    end

    def manejar_error_400(mensaje_error, chat, args)
        manejado = true

        id_mensaje = conseguir_id_mensaje args

        case mensaje_error
        when /have no rights to send a message/
            @logger.error("Me restringieron los mensajes #{chat} y"\
                          "no puedo mandar nada:\n#{mensaje_error}")
        when /have no write access to the chat/
            @logger.error('Me restringieron y solo puedo mandar mensajes de texto '\
                          "#{chat} y no puedo mandar nada.\n#{mensaje_error}")
        when /not enough rights to send (sticker|animation)s to the chat/
            @logger.error("Me restringieron los stickers y gifs #{chat}:"\
                          "\n#{mensaje_error}")
        when /(?-x:not enough rights to send )
              (?-x:(photo|document|video|audio|v(oice|ideo) note)s to the chat)/x
            @logger.error("Me restringieron la multimedia #{chat}"\
                          "\n#{mensaje_error}")
        when /message to delete not found/
            @logger.error(
                "Traté de borrar un mensaje (id mensaje: #{id_mensaje}) "\
                "muy viejo (id chat: #{chat}).",
                al_canal: false
            )
        when /message can't be deleted/
            @logger.error(
                "No pude borrar un mensaje (id mensaje: #{id_mensaje}) "\
                "(id chat: #{chat}).",
                al_canal: false
            )
        when /PEER_ID_INVALID/
            @logger.fatal("Le quise mandar un mensaje privado #{chat}"\
                          ' a alguien que no me habló primero o me bloqueó.',
                          al_canal: true)
            manejado = false
        when /chat not found/
            @logger.fatal("Quise mandar un mensaje #{chat} pero parece que el "\
                          'chat no existe o fue brutalmente DOMADO y ULTRAJADO '\
                          'por telegram', al_canal: true)
            manejado = false
        when /CHANNEL_PRIVATE/
            @logger.fatal('Error que todavía no se por que pasa pero tengo un '\
                          "problema al mandar mensajes (id: #{chat}).")
        else
            manejado = false
        end
        manejado
    end

    def manejar_error_403(mensaje_error, chat, _args)
        manejado = true

        case mensaje_error
        when /bot is not a member of the (super)?group chat/
            @logger.error("Error en #{chat}. Me fui y no puedo mandar mensajes."\
                          "\n#{mensaje_error}")
        when /bot is not a member of the channel chat/
            @logger.error("Error en #{chat}. Me fui o me sacaron los permisos de "\
                          "mandar mensaje en el canal.\n#{mensaje_error}")
        when /bot was kicked from the (super)?group chat/
            @logger.error("Error en #{chat}. Me echaron y no puedo "\
                          "mandar mensajes.\n#{mensaje_error}")
        when /bot can't send messages to bots/
            @logger.error("Error en #{chat}. No puedo hablar con otros "\
                          "bots.\n#{mensaje_error}")
            manejado = false
        when /user is deactivated/
            @logger.error("Error en #{chat}. No puedo hablar por privado con cuentas "\
                          "eliminadas.\n#{mensaje_error}")
            manejado = false
        else
            manejado = false
        end
        manejado
    end

    def manejar_error_429(mensaje_error, chat, _args)
        manejado = true

        case mensaje_error
        when /Too Many Requests: retry after/
            segundos = mensaje_error.split('{"retry_after"=>').last.split('}').first
            @logger.error("Por #{segundos} segundos no puedo mandar mensajes "\
                          "#{chat}\n#{mensaje_error}")
        else
            manejado = false
        end
        manejado
    end

    def manejar_error_502(mensaje_error, _chat, _args)
        manejado = true

        case mensaje_error
        when /Bad Gateway/
            @logger.error 'Error de un servidor externo cuando los '\
                          'servidores de telegram se intentaban '\
                          "comunicar con ellos: \n#{mensaje_error}"
        else
            manejado = false
        end
        manejado
    end

    def conseguir_id_mensaje(args)
        args && args[:message_id] ? args[:message_id] : 'no la tengo uwu'
    end
end
