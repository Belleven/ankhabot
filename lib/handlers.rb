module Handler
    class Mensaje
        MSJ_TYPES = %i[text audio document game photo
                       sticker video voice video_note contact
                       location venue poll reply_markup].freeze

        def initialize(callback, args = {})
            @callback = callback
            @permitir_editados = args[:permitir_editados] || false
            @chats_permitidos = args[:chats_permitidos]&.map(&:to_s) ||
                                %w[private group supergroup] # channel es otra opción
            @ignorar_comandos = args[:ignorar_comandos] || false
            @tipos = args[:tipos] || MSJ_TYPES
        end

        def verificar(bot, msj)
            return unless msj.is_a? Telegram::Bot::Types::Message
            return if !@permitir_editados && msj.edit_date
            return if @ignorar_comandos &&
                      Dankie.comandos.include?(bot.obtener_comando(msj))
            return unless @chats_permitidos.include?(msj.chat.type)

            verificar_tipo msj
        end

        def ejecutar(bot, msj)
            bot.public_send(@callback, msj)
        end

        private

        def verificar_tipo(msj)
            @tipos.each do |tipo|
                tipo_msj = msj.send tipo
                return true if tipo_msj && !(tipo_msj.is_a?(Array) && tipo_msj.empty?)
            end
            false
        end
    end

    class Comando
        attr_reader :cmd, :descripción

        def initialize(cmd, callback, args = {})
            @cmd = cmd
            @callback = callback
            @descripción = args[:descripción]
            @permitir_params = args[:permitir_params] || false
            @permitir_editados = args[:permitir_editados] || false
            # 'channel' es otra opción
            @chats_permitidos = args[:chats_permitidos]&.map(&:to_s) ||
                                %w[private group supergroup]
        end

        def ejecutar(bot, msj, datos_msj)
            return unless msj.is_a? Telegram::Bot::Types::Message
            return if !@permitir_editados && msj.edit_date

            unless @chats_permitidos.include?(msj.chat.type)
                bot.chat_inválido(msj, @chats_permitidos)
                return
            end

            bot.logger.info "Comando \"#{@cmd}\" en #{msj.chat.id}"
            params = [@callback, msj]
            params << datos_msj[:params] if @permitir_params

            bot.public_send(*params)
        end
    end

    class CallbackQuery
        attr_reader :clave

        def initialize(callback, clave, _args = {})
            @callback = callback
            @clave = clave
        end

        def verificar(_bot, callback)
            callback.is_a?(Telegram::Bot::Types::CallbackQuery) &&
                callback.data.start_with?("#{@clave}:")
        end

        def ejecutar(bot, callback)
            bot.logger.info "CallbackQueryHandler: callback #{callback.data} "\
                            "en #{callback.message.chat.id}"

            bot.public_send(@callback, callback)
        end
    end

    # Inicializarlo con el tipo de atributos que querés que soporte el handler
    # (los posibles son los de MSJ_TYPES). Lo podés inicializar con un solo
    # elemento (como símbolo) o con una lista no vacía de elementos
    # (strings o símbolos). Si no le pasás ningún tipo, toma todos los de MSJ_TYPES.
    class EventoDeChat
        # migrate_to_chat_id NO ESTÁ porque decidimos ignorar los mensajes
        # que contengan ese campo (ya que van a ser los últimos que existan
        # en ese chat y pueden generar quilombetes). Para saber cuándo un
        # grupo migra a supergrupo dejamos migrate_from_chat_id
        MSJ_TYPES = %i[new_chat_members left_chat_member new_chat_title
                       new_chat_photo delete_chat_photo group_chat_created
                       supergroup_chat_created channel_chat_created
                       migrate_from_chat_id pinned_message invoice
                       successful_payment connected_website passport_data].freeze

        def initialize(callback, args = {})
            @tipos = args[:tipos] || MSJ_TYPES

            @tipos.each do |atributo|
                unless MSJ_TYPES.include? atributo
                    raise "#{atributo} no es un tipo válido"
                end
            end

            @chats_permitidos = args[:chats_permitidos]&.map(&:to_s) ||
                                %w[private group supergroup] # 'channel' es otra opción
            @callback = callback
        end

        def verificar(_bot, msj)
            return unless msj.is_a? Telegram::Bot::Types::Message
            return unless @chats_permitidos.include?(msj.chat.type)

            @tipos.each do |tipo|
                atributo = msj.send tipo
                return true if atributo && !(atributo.is_a?(Array) && atributo.empty?)
            end
            false
        end

        def ejecutar(bot, msj)
            bot.public_send(@callback, msj)
        end
    end

    class InlineQuery
        def initialize(callback, _args)
            @callback = callback
        end

        def verificar(_bot, msj)
            msj.is_a? Telegram::Bot::Types::InlineQuery
        end

        def ejecutar(bot, query)
            bot.public_send(@callback, query)
        end
    end
end
