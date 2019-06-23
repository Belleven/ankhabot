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
    end

    private

    def delay_y_envio(args)
        args[:text] = args[:text].strip
        return if args[:text].nil? || args[:text].empty?

        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'typing')
        # Acá meter el delay
        @client.api.send_message(args)
    
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
        retry
    end

    def forward_message(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'typing')
        # Meter delay
        @client.api.forward_message(args)
    end

    # No estaría entendiendo por qué no toma esta función el bot durante /nisman
    # Será porque la llama desde un thread?
    def edit_message_text(args)
    	puts "\n\nAAAAAAAAA\n\n"
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'typing')
        
        puts "\n\nAAAAAAAAA\n\n"
        # Meter delay
        if args[:text].length > 0
            if args[:text].length > 4096
                args[:text] = args[:text][0..4095].strip
                @client.api.edit_message_text(args)
            else
                @client.api.edit_message_text(args)
            end
        end
    end


    def send_photo(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_photo')
        # Meter delay
        @client.api.send_photo(args)
    end

    def send_audio(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_audio')
        # Meter delay
        @client.api.send_audio(args)
    end

    def send_document(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_document')
        # Meter delay
        @client.api.send_document(args)
    end

    def send_video(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_video')
        # Meter delay
        @client.api.send_video(args)
    end

    def send_animation(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_photo')
        # Meter delay
        @client.api.send_animation(args)
    end

    def send_video_note(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'upload_video_note')
        # Meter delay
        @client.api.send_video_note(args)
    end

    def send_voice(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'record_audio')
        # Meter delay
        @client.api.send_voice(args)
    end  

    def send_location(args)
        @client.api.send_chat_action(chat_id: args[:chat_id], action: 'find_location')
        # Meter delay
        @client.api.send_location(args)
    end  

    def send_sticker(args)
    	# Meter delay
    	@client.api.send_sticker(args)
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
