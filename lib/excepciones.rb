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

    # Si pongo manejado = false es para que loggee la excepción con el backtrace
    # Tener en cuenta que hay muchas que no se loggean en el canal por spamosas

    def manejar_error_400(mensaje_error, chat, args)
        manejado = true

        id_mensaje = conseguir_id_mensaje args

        case mensaje_error
        when /have no rights to send a message/,
             /need administrator rights in the channel chat/
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
                "muy viejo #{chat}."
            )
        when /message can't be deleted/
            @logger.error(
                "No pude borrar un mensaje (id mensaje: #{id_mensaje}) #{chat}."
            )
        else
            manejado = manejar_error_400_parte_2(mensaje_error, chat, id_mensaje)
        end
        manejado
    end

    def manejar_error_400_parte_2(mensaje_error, chat, id_mensaje)
        manejado = true

        case mensaje_error
        when /PEER_ID_INVALID/
            @logger.fatal('Error extraño que indica que no puedo mandar mensajes a '\
                          'ese chat, en general es cuando el bot le habla por privado '\
                          'a alguien que nunca le habló o que lo bloqueó, pero puede '\
                          'saltar en grupos comunes también '\
                          "aparentemente: #{mensaje_error}")
        when /CHAT_SEND_GIFS_FORBIDDEN/
            @logger.fatal("Quise mandar un gif #{chat} "\
                          "pero parece que está prohibido: #{mensaje_error}")
        when /CHAT_SEND_MEDIA_FORBIDDEN/
            @logger.fatal("Quise mandar multimedia #{chat} "\
                          "pero parece que está prohibido: #{mensaje_error}")
        when /chat not found/
            @logger.fatal("Quise mandar un mensaje #{chat} pero parece que el "\
                          'chat no existe o fue brutalmente DOMADO y ULTRAJADO '\
                          'por telegram')
        when /CHANNEL_PRIVATE/
            @logger.fatal('Error que todavía no se por que pasa pero tengo un '\
                          "problema al mandar mensajes (id: #{chat}).")
        when /group chat was deactivated/
            @logger.fatal("Error: el grupo fue eliminado (id: #{chat}).")
        when /CHAT_RESTRICTED/
            @logger.fatal("Error: chat restringido (id: #{chat}).")
        when /user is deactivated/
            @logger.fatal('Le intenté hablar por privado a una '\
                          "cuenta eliminada #{chat}.")
        else
            manejado = manejar_error_400_parte_3(mensaje_error, chat, id_mensaje)
        end
        manejado
    end

    def manejar_error_400_parte_3(mensaje_error, chat, _id_mensaje)
        manejado = true

        case mensaje_error
        when /message to edit not found/
            @logger.fatal("Borraron el mensaje que iba a editar #{chat}")
        when /MESSAGE_ID_INVALID/
            @logger.fatal('Extraño error con el id mensaje, no sabemos por qué salta '\
                          "todavía #{chat}: #{mensaje_error}")
        when /CHAT_WRITE_FORBIDDEN/ # esta aparece tambien con código de error 403
            @logger.error("No puedo mandar mensajes #{chat}.")
        when /CHAT_SEND_STICKERS_FORBIDDEN/
            @logger.fatal("Quize mandar un sticker #{chat}, pero parece "\
                'que esta prohibido.')
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
        when /bot was kicked from the ((super)?group|channel) chat/
            @logger.error("Error en #{chat}. Me echaron y no puedo "\
                          "mandar mensajes.\n#{mensaje_error}")
        when /bot can't send messages to bots/
            @logger.error("Error en #{chat}. No puedo hablar con otros "\
                          "bots.\n#{mensaje_error}")
            manejado = false
        when /user is deactivated/
            @logger.error("Error en #{chat}. No puedo hablar por privado con cuentas "\
                          "eliminadas.\n#{mensaje_error}")
        when /bot was blocked by the user/
            @logger.error("Error en #{chat}. Ese usuario me bloqueó.")
        when /CHAT_WRITE_FORBIDDEN/ # esta aparece tambien con código de error 400
            @logger.error("No puedo mandar mensajes #{chat}.")
        else
            manejado = false
        end
        manejado
    end

    def manejar_error_409(mensaje_error, _chat, _args)
        manejado = true

        case mensaje_error
        when /terminated\ by\ other\ getUpdates\ request;
             \ make\ sure\ that\ only\ one\ bot\ instance\ is\ running/x
            @logger.fatal(
                'Error turbina de telegram, parece que detecta como que hay dos '\
                'o más instancias de dankie corriendo a la vez al hacer get_updates '\
                "en el bucle principal.\n#{mensaje_error}",
                al_canal: true
            )
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
