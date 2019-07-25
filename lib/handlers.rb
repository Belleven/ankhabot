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
                break if msj_type
            end

            return unless msj_type

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

    # Este es el handler general, lo ideal sería que cada vez que se necesite
    # un handler para un tipo de evento que no tenga, se armen uno nuevo y no usen este
    # pero bueno de última queda este por si se necesita.
    # Aunque bueno, eso genera mucho código repetido, veremos qué hacer en un futuro.
    class EventoDeChat
        MSJ_TYPES = %i[new_chat_members left_chat_member new_chat_title
                       new_chat_photo delete_chat_photo group_chat_created
                       supergroup_chat_created channel_chat_created pinned_message].freeze

        def initialize(callback, args = {})
            @atributos = args[:types] || MSJ_TYPES
            @callback = callback
        end

        def check_message(bot, msj)
            return unless msj.is_a? Telegram::Bot::Types::Message

            atributo = nil
            @atributos.each do |tipo|
                atributo = msj.send tipo
                break if atributo
            end

            return unless atributo

            bot.public_send(@callback, msj)
        end
    end

    # Volar estas dos, usar solo EventoDeChat y ver como parametrizarlo bien
    class NuevosMiembros
        def initialize(callback)
            @callback = callback
        end

        def check_message(bot, msj)
            return unless msj.is_a? Telegram::Bot::Types::Message
            return if msj.new_chat_members.nil? || msj.new_chat_members.empty?

            bot.public_send(@callback, msj)
        end
    end

    class MigrarASupergrupo
    end
end
