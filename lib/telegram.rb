require 'telegram/bot'
require 'httpclient'

class TelegramAPI
    attr_reader :client, :token, :ultima_excepción_data

    # token es String, logger es Logger
    def initialize(token, logger)
        Telegram::Bot.configure do |config|
            config.adapter = :httpclient
        end
        @client = Telegram::Bot::Client.new token, logger: logger
        @token = token
        @excepciones = ManejoExcepciones.new logger
    end

    def capturar(excepción)
        @excepciones.capturar excepción
    end

    # Acá dentro se podrían agregar excepciones si vemos que rompe mucho
    def get_updates(args)
        actualizaciones = @client.api.get_updates args

        unless actualizaciones['ok']
            @client.logger.error "Mala update:\n#{actualizaciones}"
            return
        end
        return if actualizaciones['result'].empty?

        actualizaciones
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

        editar(:edit_message_text, args) unless args[:text].empty?
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

    def send_media_group(args)
        enviar(:send_media_group, args, 'upload_photo')
    end

    def edit_message_caption(args)
        editar(:edit_message_caption, args)
    end

    def edit_message_media(args)
        editar(:edit_message_media, args)
    end

    def edit_message_reply_markup(args)
        editar(:edit_message_reply_markup, args)
    end

    def answer_callback_query(args)
        @client.api.answer_callback_query args
    rescue Telegram::Bot::Exceptions::ResponseError => e
        case e.message
        when /query is too old and response timeout expired or query ID is invalid/
            # No hacer nada LEL
        else
            raise e
        end
    end

    def delete_message(args)
        @client.api.delete_message args
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if (callback = args[:callback]) && e.error_code.to_i == 403
            answer_callback_query(
                callback_query_id: callback.id,
                text: 'Gomenasai, no tengo permisos para borrar ese mensaje uwu'
            )
        end

        raise unless args[:ignorar_excepciones_telegram]

        @excepciones.loggear(e, args)
    end

    def unban_chat_member(args)
        @client.api.unban_chat_member args
    end

    def pin_chat_message(args)
        @client.api.pin_chat_message args
    end

    def kick_chat_member(args)
        @client.api.kick_chat_member args
    end

    def unpin_chat_message(args)
        @client.api.unpin_chat_message args
    end

    def delete_chat_photo(args)
        @client.api.delete_chat_photo args
    end

    # rubocop:disable Naming/AccessorMethodName
    def set_chat_title(args)
        @client.api.set_chat_title args
    end

    def set_chat_description(args)
        @client.api.set_chat_description args
    end
    # rubocop:enable Naming/AccessorMethodName

    def get_chat_member(args)
        @client.api.get_chat_member args
    end

    private

    def enviar(método_edición, args, acción = nil)
        # Si hay una acción que mandar, la mando
        if acción
            @client.api.send_chat_action(chat_id: args[:chat_id],
                                         action: acción)
        end

        # Mando el mensaje (de texto, sticker, lo que sea)
        enviado = @client.api.send(método_edición, args)
        # Como los métodos que tienen acción son los que envían mensajes,
        # voy a aumentar las estadísticas de mensajes enviados acá.
        Estadísticas::Contador.incr('msj_enviados', hora: Time.now.to_i, intervalo: 600)
        enviado

    # Si hay un error de telegram, loggeo si es conocido,
    # si no lo vuelvo a lanzar
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if e.error_code.to_i == 400
            analizar_excepción_400_enviar(args, e)
            retry
        else
            # Esto es para poder loggear el chat_id y luego hace raise para que no
            # continue con la ejecución normal
            @excepciones.loggear(e, args)
            raise
        end
    end

    # ignorar_excepciones_telegram: true para capturar cualquier excepción al editar
    # un msj y que siga la ejecución del método
    def editar(método_edición, args)
        @client.api.send(método_edición, args)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if (callback = args[:callback]) && e.error_code.to_i == 403
            answer_callback_query(
                callback_query_id: callback.id,
                text: 'Gomenasai, no tengo permisos para editar ese mensaje uwu'
            )
        elsif %r{(wrong\ type\ of\ the\ web\ page\ content)|
                 (wrong\ file\ identifier/HTTP\ URL\ specified)}x.match? e.message
            @client.logger.error(
                'Error al querer editar un mensaje con nueva multimedia de internet, '\
                'esto es solo para los args que rompieron, después se va a relanzar '\
                "la excepción.\nargs: #{args}"
            )
        end

        raise unless args[:ignorar_excepciones_telegram]

        @excepciones.loggear(e, args)
    end

    def analizar_excepción_400_enviar(args, exc)
        case exc.message
        when /replied message not found/
            @client.logger.error(
                'No puedo responder a un mensaje borrado (ID: '\
                "#{args[:reply_to_message_id]}) en #{args[:chat_id]}. "\
                "Error:\n#{exc.message}"
            )
        when /group chat was upgraded to a supergroup chat/
            corte_al_inicio = exc.message.split('{"migrate_to_chat_id"=>').last
            id_supergrupo = corte_al_inicio.split('}').first

            @client.logger.error(
                "Error en #{args[:chat_id]}. El grupo se actualizó y ahora es un "\
                "supergrupo (#{id_supergrupo}).\n#{exc.message}"
            )
            args[:chat_id] = id_supergrupo.to_i
        when /wrong type of the web page content/,
             %r{wrong file identifier/HTTP URL specified}
            @client.logger.error(
                'Error al querer mandar multimedia de internet, esto es solo para '\
                "los args que rompieron, después se va a relanzar la excepción.\n"\
                "args: #{args}"
            )
            raise
        else
            raise
        end
        args[:reply_to_message_id] = nil
    end

    # Tengo acceso a toda la api de telegram (bot.api) desde esta clase
    def method_missing(method_name, **args)
        super unless @client.api.respond_to?(method_name)
        @client.api.send(method_name, **args)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        # Si la excepción fue manejada entonces no hay que loggear
        raise unless @excepciones.loggear(e, args)
    end

    def respond_to_missing?(method_name)
        @client.api.respond_to?(method_name) || super
    end
end
