require 'telegram/bot'
require 'httpclient'

class TelegramAPI
    attr_reader :client, :token

    # token es String, logger es Logger
    def initialize(token, logger)
        Telegram::Bot.configure do |config|
            config.adapter = :httpclient
        end
        @client = Telegram::Bot::Client.new token, logger: logger
        @token = token
    end

    def send_message(args)
        # Me fijo que haya un texto para mandar
        return unless args[:chat_id] && args[:text] && !args[:text].empty?

        resultado = nil
        # Copio el texto pues args[:text] va a ser lo
        # que mande en cada bloque
        texto = args[:text]

        # Itero de a bloques de 4096
        inicio = 0
        fin = [texto.length, 4096].min

        while inicio != fin

            # Mando el blocazo
            args[:text] = texto[inicio..(fin - 1)].strip

            unless args[:text].nil? || args[:text].empty?
                resultado = enviar(:send_message, args, 'typing')
            end

            # Actualizo índices
            inicio = fin
            fin = [texto.length, fin + 4096].min
        end
        resultado
    end

    def edit_message_text(args)
        # Chequeo que no se pase el tamaño
        if args[:text].length > 4096
            # Ver que onda con el tema de entidades html
            args[:text] = args[:text][0..4095]
        end
        args[:text].strip

        enviar(:edit_message_text, args) unless args[:text].empty?
    end

    def forward_message(args)
        enviar(:forward_message, args)
    end

    def send_photo(args)
        enviar(:send_photo, args, 'upload_photo')
    end

    def send_audio(args)
        enviar(:send_audio, args, 'upload_audio')
    end

    def send_document(args)
        enviar(:send_document, args, 'upload_document')
    end

    def send_video(args)
        enviar(:send_video, args, 'upload_video')
    end

    def send_animation(args)
        enviar(:send_animation, args, 'upload_video')
    end

    def send_video_note(args)
        enviar(:send_video_note, args, 'upload_video_note')
    end

    def send_voice(args)
        enviar(:send_voice, args, 'upload_audio')
    end

    def send_location(args)
        enviar(:send_location, args, 'find_location')
    end

    def send_sticker(args)
        enviar(:send_sticker, args)
    end

    def answer_callback_query(args)
        enviar :answer_callback_query, args
    end

    private

    def enviar(función_envío, args, acción = nil)
        # Si hay una acción que mandar, la mando
        if acción
            @client.api.send_chat_action(chat_id: args[:chat_id],
                                         action: acción)
        end

        # TODO: meter delay para no sobrepasar los
        # límites de flood de telegram

        # Mando el mensaje (de texto, sticker, lo que sea)
        @client.api.send(función_envío, args)

    # Si hay error de conexión, lo reintento
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError,
           HTTPClient::ReceiveTimeoutError, Net::OpenTimeout => e
        retry
    # Si hay un error de telegram, loggeo si es conocido,
    # si no lo vuelvo a lanzar
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.to_s

        when /Too Many Requests: retry after/
            @client.logger.error('Por un tiempo no puedo mandar mensajes '\
                                 "en #{args[:chat_id]}\n#{e}")

        when /have no rights to send a message/
            @client.logger.error("Me restringieron los mensajes en #{args[:chat_id]}")

        when /reply message not found/
            @client.logger.error('No puedo responder a un mensaje '\
                                 "borrado (ID: #{args[:reply_to_message_id]}) "\
                                 "en #{args[:chat_id]}",
                                 al_canal: true)
            args[:reply_to_message_id] = nil
            retry

        when /bot was kicked from the (super)?group chat/
            @client.logger.fatal("Me echaron de este grupete: #{args[:chat_id]}, "\
                                 'y no puedo mandar mensajes')
            raise

        when /Forbidden: bot is not a member of the (super)?group chat/
            @client.logger.fatal("Me fui de este grupete: #{args[:chat_id]}, "\
                                 'y no puedo mandar mensajes')
            raise

        when /Forbidden: bot can't initiate conversation with a user/
            @client.logger.fatal("Me fui de este grupete: #{args[:chat_id]}, "\
                                 'y no puedo mandar mensajes')
            raise

        when /USER_IS_BOT/
            texto, backtrace = @client.logger.excepcion_texto(e)
            texto << "\nLe quise mandar un mensaje privado a "\
                     "este bot: #{args[:chat_id]}"
            @client.logger.fatal(texto, al_canal: true, backtrace: backtrace)
            raise

        when /chat not found/
            @client.logger.fatal("Chat inválido: #{args[:chat_id]}", al_canal: true)
            # Relanzo excepción
            raise

        when /message text is empty/
            @client.logger.fatal('Quise mandar un mensaje '\
                                 "vacío en el chat: #{args[:chat_id]}",
                                 al_canal: true)

        when /message is too long/
            @client.logger.fatal('Quise mandar un mensaje '\
                                 "muy largo en el chat: #{args[:chat_id]}",
                                 al_canal: true)
            args[:text] = args[:text][0..4095]
            retry

        when /PEER_ID_INVALID/
            @client.logger.error('Le quise mandar un mensaje privado a '\
                                 'alguien que no me habló primero o me '\
                                 "bloqueó (ID: #{args[:chat_id]}")
            # Vuelvo a relanzar la excepción (esto fue solo para registral la id)
            raise

        when %r{(?-x:wrong file identifier/HTTP URL specified)|
                (?-x:wrong type of the web page content)}x
            @client.logger.error('Error al mandar archivo al '\
                                 "chat (ID: #{args[:chat_id]})")

        when /(?-x:not enough rights to send )
                (?-x:(photo|document|video|audio|v(oice|ideo) note)s to the chat)/x
            @client.logger.error("Me restringieron la multimedia en #{args[:chat_id]}")

        when /not enough rights to send (sticker|animation)s to the chat/
            @client.logger.error("Me restringieron stickers/gifs en #{args[:chat_id]}")

        when /CHAT_SEND_GIFS_FORBIDDEN/
            @client.logger.error("Me restringieron los gifs en #{args[:chat_id]}")

        when /CHAT_SEND_STICKERS_FORBIDDEN/
            @client.logger.error("Me restringieron los stickers en #{args[:chat_id]}")

        when /CHAT_SEND_MEDIA_FORBIDDEN/
            @client.logger.error("Me restringieron la multimedia en #{args[:chat_id]}")

        when /CHAT_WRITE_FORBIDDEN/
            @client.logger.error("Me restringieron los mensajes en #{args[:chat_id]}")

        when /group chat was upgraded to a supergroup chat/
            @client.logger.error("#{args[:chat_id]} migró a otra id, pronto va a "\
                                 'llegar el update sobre eso y ahí actualizo las '\
                                 'claves de la base de datos')

        else
            raise
        end
    end

    # Tengo acceso a toda la api de telegram (bot.api) desde esta clase
    def method_missing(method_name, *args)
        super unless @client.api.respond_to?(method_name)
        @client.api.send(method_name, *args)
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError,
           HTTPClient::ReceiveTimeoutError, Net::OpenTimeout => e
        texto, backtrace = @client.logger.excepcion_texto(e)
        @client.logger.error texto, backtrace: backtrace
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        texto, backtrace = @client.logger.excepcion_texto(e)

        if !texto.include?('wrong user_id specified') ||
           !backtrace.include?('obtener_enlace_usuario')
            @client.logger.error texto, backtrace: backtrace
        end

        raise e
    end

    def respond_to_missing?(method_name)
        @client.api.respond_to?(method_name) || super
    end
end
