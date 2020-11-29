# Extensión de Dankie para ver y modificar configuraciones
class Dankie
    add_handler Handler::Comando.new(
        :configuraciones,
        :configuraciones,
        chats_permitidos: %i[group supergroup],
        descripción: 'Te muestro las configuraciones del grupete'
    )

    add_handler Handler::CallbackQuery.new(
        :callback_config_seleccionada,
        'config_seleccionada'
    )

    add_handler Handler::CallbackQuery.new(
        :callback_modificar_config,
        'modificar_config'
    )

    # Diccionario de Categorías. Uso: {clave de categoría => descripción}
    CATEGORIAS = { admite_triggers_globales: 'Admite Triggers Globales',
                   admite_x2: 'Habilitar x2',
                   admite_anuncios: 'Habilitar anuncios' }.freeze

    def configuraciones(msg)
        error_msj = "Ese comando es solo para admins, #{TROESMAS.sample}."
        return unless es_admin(msg.from.id, msg.chat.id, msg.message_id, error_msj)

        Configuración.redis ||= @redis
        respuesta, opciones = obtener_mensaje_configuraciones(msg.chat.id)

        @tg.send_message(chat_id: msg.chat.id,
                         text: respuesta,
                         reply_markup: opciones,
                         parse_mode: :html)
    end

    def callback_config_seleccionada(callback)
        return unless es_admin(callback.from.id,
                               callback.message.chat.id,
                               callback.message.message_id)

        match = callback.data.match(/config_seleccionada:(?<categoria>.+)/)

        case match[:categoria]
        when 'cerrar_config'
            chat_id = callback.message.chat.id
            respuesta, _opciones = obtener_mensaje_configuraciones(chat_id)
            @tg.edit_message_text(chat_id: chat_id,
                                  parse_mode: :html,
                                  text: respuesta,
                                  message_id: callback.message.message_id,
                                  disable_web_page_preview: true,
                                  disable_notification: true)
            return
        end

        crear_arreglo_y_enviar(match, callback)
    end

    def callback_modificar_config(callback)
        return unless es_admin(callback.from.id,
                               callback.message.chat.id,
                               callback.message.message_id)

        match = callback.data.match(/modificar_config:(?<categoria>.+):(?<acción>.+)/)
        id_grupo = callback.message.chat.id

        case match[:acción]
        when 'Sí'
            Configuración.poner_config(id_grupo, match[:categoria], 1)
        when 'No'
            Configuración.poner_config(id_grupo, match[:categoria], 0)
        end

        text, options = obtener_mensaje_configuraciones(id_grupo)

        @tg.edit_message_text(chat_id: id_grupo,
                              parse_mode: :html,
                              text: text,
                              message_id: callback.message.message_id,
                              reply_markup: options,
                              disable_web_page_preview: true,
                              disable_notification: true)
    end

    def obtener_mensaje_configuraciones(chat_id)
        respuesta = '<b>Configuraciones del chat</b>'
        arr = []
        CATEGORIAS.each do |categoria, mensaje|
            valor = parsear_valor_booleano(Configuración.config(chat_id, categoria))
            respuesta << "\n-#{mensaje}: #{valor}"
            button = Telegram::Bot::Types::InlineKeyboardButton.new(
                text: "Modificar: #{mensaje}",
                callback_data: "config_seleccionada:#{categoria}"
            )
            arr << button
        end

        button = Telegram::Bot::Types::InlineKeyboardButton.new(
            text: 'Terminar',
            callback_data: 'config_seleccionada:cerrar_config'
        )
        arr << button

        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        [respuesta, opciones]
    end

    private

    # Parseo las categorías a "Sí" o "No". Por default, "Sí"
    # Caso default ocurre cuando nunca se modificó esa categoría.
    # Si agregamos categorías numéricas, crear otro diccionario de categorías
    # Junto con su parser
    def parsear_valor_booleano(valor)
        return '<b>Si</b>' if valor.nil? || valor.to_i.positive?

        '<b>No</b>'
    end

    def crear_arreglo_y_enviar(match, callback)
        arr = [
            [
                Telegram::Bot::Types::InlineKeyboardButton.new(
                    text: 'Sí',
                    callback_data: "modificar_config:#{match[:categoria]}:Sí"
                ),
                Telegram::Bot::Types::InlineKeyboardButton.new(
                    text: 'No',
                    callback_data: "modificar_config:#{match[:categoria]}:No"
                )
            ],
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: 'Cancelar',
                callback_data: "modificar_config:#{match[:categoria]}:Cancelar"
            )
        ]
        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        @tg.edit_message_text(
            chat_id: callback.message.chat.id,
            parse_mode: :html,
            text: callback.message.text,
            reply_markup: opciones,
            message_id: callback.message.message_id,
            disable_web_page_preview: true,
            disable_notification: true
        )
    end
end
