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
        @excepciones = ManejoExcepciones.new @logger
    end

    def capturar(excepción)
        @excepciones.capturar excepción
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

    def send_media_group(args)
        enviar(:send_media_group, args, 'upload_photo')
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

        # Mando el mensaje (de texto, sticker, lo que sea)
        enviado = @client.api.send(función_envío, args)
        # Como los métodos que tienen acción son los que envían mensajes,
        # voy a aumentar las stats de mensajes enviados acá.
        Stats.incr("msj_enviados:#{Time.now.strftime('%Y-%m-%d')}")
        enviado

    # Si hay un error de telegram, loggeo si es conocido,
    # si no lo vuelvo a lanzar
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if e.error_code.to_i == 400
            args[:reply_to_message_id] = nil

            if e.message.include?('reply message not found')
                @client.logger.error('No puedo responder a un mensaje '\
                                     "borrado (ID: #{args[:reply_to_message_id]}) "\
                                     "en #{args[:chat_id]}. Error:\n#{e.message}")
            elsif e.message.include?('group chat was upgraded to a supergroup chat')
                corte_al_inicio = e.message.split('{"migrate_to_chat_id"=>').last
                id_supergrupo = corte_al_inicio.split('}').first

                @client.logger.error("Error en #{args[:chat_id]}. El grupo se "\
                                     'actualizó y ahora es unsupergrupo '\
                                     "(#{id_supergrupo}).\n#{e.message}",
                                     al_canal: true)
                args[:chat_id] = id_supergrupo.to_i
            else
                raise
            end

            retry
        else
            @excepciones.loggear(e, args)
            raise
        end
    end

    # Tengo acceso a toda la api de telegram (bot.api) desde esta clase
    def method_missing(method_name, *args)
        super unless @client.api.respond_to?(method_name)
        @client.api.send(method_name, *args)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        # Si la excepción fue manejada entonces no hay que loggear
        @excepciones.loggear(e, args)
        raise
    end

    def respond_to_missing?(method_name)
        @client.api.respond_to?(method_name) || super
    end
end
