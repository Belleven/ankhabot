module Handler
    class Mensaje
        MSJ_TYPES = %i[text audio document game photo
                       sticker video voice video_note contact
                       location venue poll].freeze

        def initialize(callback, args = {})
            @callback = callback
            @allow_edited = args[:allow_edited] || false
            @allowed_chats = args[:allowed_chats]&.map(&:to_s) || %w[private group supergroup] # 'channel' es otra opción
            @msj_types = args[:types] || MSJ_TYPES
        end

        def check_message(bot, msj)
            return unless msj.is_a? Telegram::Bot::Types::Message
            return if !@allow_edited && msj.edit_date

            return unless @allowed_chats.include?(msj.chat.type)

            msj_type = nil
            @msj_types.each do |type|
                msj_type = msj.send type
                break if msj_type && (msj_type.is_a?(Array) ? !msj_type.empty? : true)
            end

            return unless msj_type && (msj_type.is_a?(Array) ? !msj_type.empty? : true)

            bot.public_send(@callback, msj)
        end
    end

    class Comando
        attr_reader :cmd, :description
        def initialize(cmd, callback, args = {})
            @cmd = cmd
            @callback = callback
            @description = args[:description]
            @allow_params = args[:allow_params] || false
            @allow_edited = args[:allow_edited] || false
        end

        def check_message(bot, msj)
            return unless msj.is_a? Telegram::Bot::Types::Message

            return if !@allow_edited && msj.edit_date

            cmd = bot.get_command(msj)
            return if @cmd != cmd

            bot.logger.info "CommandHandler: comando \"#{@cmd}\" en #{msj.chat.id}"
            if @allow_params
                bot.public_send(@callback, msj, bot.get_command_params(msj))
            else
                bot.public_send(@callback, msj)
            end
        end
    end

    class CallbackQuery
        def initialize(callback, patrón, _args = {})
            @callback = callback
            @patrón = patrón
        end

        def check_message(bot, msj)
            return unless msj.is_a? Telegram::Bot::Types::CallbackQuery

            return unless @patrón =~ msj.data

            bot.logger.info "CallbackQueryHandler: patrón #{@patrón} en #{msj.chat.id}"
            bot.public_send(@callback, msj)
        end
    end

    # Inicializarlo con el tipo de atributos que querés que soporte el handler
    # (los posibles son los de MSJ_TYPES). Lo podés inicializar con un solo
    # elemento (como string o símbolo) o con una lista no vacía de elementos
    # (strings o símbolos). Si no le pasás ningún tipo, toma todos los de MSJ_TYPES.
    class EventoDeChat
        MSJ_TYPES = %i[new_chat_members left_chat_member new_chat_title
                       new_chat_photo delete_chat_photo group_chat_created
                       supergroup_chat_created channel_chat_created pinned_message].freeze

        def initialize(callback, tipo = nil)
            if tipo.nil?
                @atributos = MSJ_TYPES
            elsif tipo.is_a?(String) || tipo.is_a?(Symbol)
                @atributos = [tipo].map(&:to_sym)
            elsif tipo.is_a? Array && !tipo.empty?
                tipo.each do |_elem|
                    unless tipo.is_a?(String) || tipo.is_a?(Symbol)
                        raise "#{atributo} no es un String ni un Symbol"
                    end
                end
                @atributos = tipo.map(&:to_sym)
            else
                raise "''tipo'' solo puede ser un String, Symbol o un Array no vacío de String/Symbol"
            end

            @atributos.each do |atributo|
                unless MSJ_TYPES.include? atributo
                    raise "#{atributo} no es un tipo válido"
                end
            end

            @callback = callback
        end

        def check_message(bot, msj)
            return unless msj.is_a? Telegram::Bot::Types::Message

            atributo = nil
            @atributos.each do |tipo|
                atributo = msj.send tipo
                break if atributo && (atributo.is_a?(Array) ? !atributo.empty? : true)
            end

            return unless atributo && (atributo.is_a?(Array) ? !atributo.empty? : true)

            bot.public_send(@callback, msj)
        end
    end
end
