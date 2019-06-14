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
            args[:text] = texto[inicio..fin-1]
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

        @client.api.send_message(args)
    rescue Faraday::ConnectionFailed, Net::OpenTimeout => e
        @client.logger.error(e)
        retry
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @client.logger.error(e)
        raise e
    end

    # tengo acceso a toda la api de telegram (bot.api) desde la clase Dankie
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
