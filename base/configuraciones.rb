# Extensión de Dankie para ver y modificar configuraciones
class Dankie
    add_handler Handler::Comando.new(
        :configuraciones,
        :configuraciones,
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
                   admite_anuncios: 'Habilitar anuncios',
                   admite_pole: 'Habilitar Nisman',
                   admite_rep: 'Habilitar reputación' }.freeze

    def configuraciones(msj)
        error_msj = "Ese comando es solo para admins, #{TROESMAS.sample}."
        return if msj.chat.type != 'private' &&
                  !es_admin(msj.from.id, msj.chat.id, msj.message_id, error_msj)

        Configuración.redis ||= @redis
        respuesta, opciones = obtener_mensaje_configuraciones(msj.chat.id)

        @tg.send_message(chat_id: msj.chat.id,
                         text: respuesta,
                         reply_markup: opciones,
                         parse_mode: :html)
    end

    def callback_config_seleccionada(callback)
        return if callback.message.chat.type != 'private' &&
                  !es_admin(callback.from.id, callback.message.chat.id,
                            callback.message.message_id)

        match = callback.data.match(/config_seleccionada:(?<categoria>.+)/)

        case match[:categoria]
        when 'cerrar_config'
            chat_id = callback.message.chat.id
            respuesta, _opciones = obtener_mensaje_configuraciones(chat_id)
            # Si falla al editar el mensaje como el método termina de ejecutarse
            # no molesta que tire la excepción, pero igual no le pongo
            # ignorar_excepciones_telegram: true para que no loggee la excepción molesta
            @tg.edit_message_text(chat_id: chat_id,
                                  parse_mode: :html,
                                  text: respuesta,
                                  message_id: callback.message.message_id,
                                  disable_web_page_preview: true,
                                  disable_notification: true,
                                  callback: callback)
            return
        end

        crear_arreglo_y_enviar(match, callback)
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if e.message =~ /message is not modified/
            @tg.answer_callback_query(callback_query_id: callback.id)
        end
    end

    def callback_modificar_config(callback)
        return if callback.message.chat.type != 'private' &&
                  !es_admin(callback.from.id, callback.message.chat.id,
                            callback.message.message_id)

        match = callback.data.match(/modificar_config:(?<categoria>.+):(?<acción>.+)/)
        id_grupo = callback.message.chat.id

        case match[:acción]
        when 'Sí'
            Configuración.poner_config(id_grupo, match[:categoria], 1)
        when 'No'
            Configuración.poner_config(id_grupo, match[:categoria], 0)
        end

        texto, options = obtener_mensaje_configuraciones(id_grupo)

        editar_mensaje_tablero_modificar_config(id_grupo, texto, callback, options)
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

        categoría = match[:categoria].split('_')[1..].join(' ').capitalize
        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr

        # No molesta si rompe acá porque se termina la ejecución justo después, pero
        # le pongo ignorar_excepciones_telegram: true para que termine bien
        @tg.edit_message_text(
            chat_id: callback.message.chat.id,
            parse_mode: :html,
            text: "Editando: <b>#{categoría}</b>",
            reply_markup: opciones,
            message_id: callback.message.message_id,
            callback: callback,
            ignorar_excepciones_telegram: true
        )
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

    def editar_mensaje_tablero_modificar_config(id_grupo, texto, callback, options)
        # No molesta si rompe acá porque se termina la ejecución justo después,
        # pero no le pongo ignorar_excepciones_telegram: true para que no loggee la
        # excepción molesta
        @tg.edit_message_text(
            chat_id: id_grupo,
            parse_mode: :html,
            text: texto,
            message_id: callback.message.message_id,
            reply_markup: options,
            callback: callback
        )
    rescue Telegram::Bot::Exceptions::ResponseError => e
        if e.message =~ /message is not modified/
            @tg.answer_callback_query(callback_query_id: callback.id)
        end
    end
end
