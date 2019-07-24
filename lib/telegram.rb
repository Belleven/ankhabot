require 'telegram/bot'

class TelegramAPI
    attr_reader :client

    # token es String, logger es Logger
    def initialize(token, logger)
        @client = Telegram::Bot::Client.new token, logger: logger
    end

    def send_message(args)
        texto = args[:text]

        return unless args[:chat_id] && args[:text] && !texto.empty?

        # Itero de a bloques de 4096
        inicio = 0
        fin = [texto.length, 4096].min

        while inicio != fin

            # Mando el blocazo
            args[:text] = texto[inicio..fin - 1]
            resultado = delay_y_envio(args)

            inicio = fin
            fin = [texto.length, fin + 4096].min

        end

        resultado
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if e.to_s.include? 'have no rights to send a message'
            @client.logger.log(Logger::ERROR, 'Me restringieron los mensajes en ' + args[:chat_id].to_s)
        else
            raise
        end
    end

    def forward_message(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'typing')
        # Meter delay
        @client.api.forward_message(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if e.to_s.include? 'have no rights to send a message'
            @client.logger.log(Logger::ERROR, 'Me restringieron los mensajes en ' + args[:chat_id].to_s)
        else
            raise
        end
    end

    def edit_message_text(args)
        # Meter delay
        unless args[:text].empty?
            if args[:text].length > 4096
                args[:text] = args[:text][0..4095].strip
                @client.api.edit_message_text(args)
            else
                @client.api.edit_message_text(args)
            end
        end
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if e.to_s.include? 'have no rights to send a message'
            @client.logger.log(Logger::ERROR, 'Me restringieron los mensajes en ' + args[:chat_id].to_s)
        else
            raise
        end
    end

    def send_photo(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_photo')
        # Meter delay
        @client.api.send_photo(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    def send_audio(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_audio')
        # Meter delay
        @client.api.send_audio(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    def send_document(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_document')
        # Meter delay
        @client.api.send_document(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    def send_video(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_video')
        # Meter delay
        @client.api.send_video(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    def send_animation(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_video')
        # Meter delay
        @client.api.send_animation(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    def send_video_note(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_video_note')
        # Meter delay
        @client.api.send_video_note(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    def send_voice(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_audio')
        # Meter delay
        @client.api.send_voice(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    def send_location(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'find_location')
        # Meter delay
        @client.api.send_location(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    def send_sticker(args)
        # Meter delay
        @client.api.send_sticker(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    private

    def delay_y_envio(args)
        args[:text] = args[:text].strip
        return if args[:text].nil? || args[:text].empty?

        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'typing')
        # Acá meter el delay
        @client.api.send_message(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout
        retry
    end

    # Tengo acceso a toda la api de telegram (bot.api) desde la clase Dankie
    # suena horrible pero está bueno y pude hacer unos rescue
    def method_missing(method_name, *args)
        super unless @client.api.respond_to?(method_name)
        @client.api.send(method_name, *args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
        @client.logger.error(e)
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @client.logger.error(e)
        raise e
    end

    def respond_to_missing?(method_name)
        @client.api.respond_to?(method_name) || super
    end
end
