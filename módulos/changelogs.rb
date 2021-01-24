class Dankie
    add_handler Handler::Comando.new(
        :changelogs,
        :changelogs,
        permitir_params: false,
        descripción: 'Changelogs del bot'
    )

    add_handler Handler::CallbackQuery.new(
        :callback_confirmar_anuncio_changelog,
        'anunciar_cambio'
    )

    # Metodo que envia el contenido del archivo changelogs
    def changelogs(msj)
        archivo = File.open(CHANGELOG, 'r') { |f| archivo = f.read }

        # Separa en un array los diferentes changelogs
        changelogs = archivo.split(/\n\s*\n(?=Versión )/)

        # Se consigue un array de versiones para los botones
        número_versiones = changelogs.map do |elemento|
            elemento.scan(/\AVersión (\d(\.\d)*)\s*\n/).first.first
        end

        # Se cambia las versiones a negrita y cursiva
        changelogs.map! do |elemento|
            elemento.gsub(/\A(Versión \d(\.\d)*)\.*/, '<b><i>\1</i></b>')
        end

        mandar_botonera(msj, changelogs, número_versiones: número_versiones)
    end

    # Metodo para conseguir la ultima version del changelogs
    def changelog_version_actual
        archivo = File.open(CHANGELOG, 'r') { |f| archivo = f.read }

        # Separa en un array los diferentes changelogs
        archivo.split(/\n\s*\n(?=Versión )/).first
    end

    def callback_confirmar_anuncio_changelog(callback)
        match = callback.data.match(/anunciar_cambio:(?<acción>.+)/)

        return unless dev_responde_callback(callback)

        id_msj_anuncio_cambio = @redis.get('versión:id_tablero_anuncio')
        if id_msj_anuncio_cambio.nil?
            @tg.answer_callback_query(
                callback_query_id: callback.id,
                text: 'Tablero respondido'
            )
            return
        elsif id_msj_anuncio_cambio.to_i != callback.message.message_id
            @tg.answer_callback_query(
                callback_query_id: callback.id,
                text: 'Este tablero ya no se puede utilizar'
            )
            return
        end

        # En caso que se acepte, se procede a anunciar a todos
        # los grupos el cambio de versión
        if match[:acción] == 'confirmar'
            editar_tablero_anuncio_changelog(callback, 'aceptado')
            anunciar(
                callback.from,
                callback.message.chat.id,
                "Acaba de salir una nueva versión mía:\n\n#{changelog_version_actual}"
            )
            @redis.set('versión', VERSIÓN)
        else
            editar_tablero_anuncio_changelog(callback, 'rechazado')
        end

        @redis.del('versión:id_tablero_anuncio')
        @redis.del('versión:versión_tablero_anuncio')
    end

    def editar_tablero_anuncio_changelog(callback, resultado)
        usuario = obtener_enlace_usuario(callback.from, callback.chat_instance) || 'dou'
        texto = "Anuncio #{resultado} por #{usuario} (#{callback.from.id})."

        @tg.edit_message_text(
            chat_id: callback.message.chat.id,
            parse_mode: :html,
            text: texto,
            message_id: callback.message.message_id,
            disable_web_page_preview: true,
            disable_notification: true
        )
    end

    def confirmar_anuncio_changelog(versión_nueva, versión_antigua)
        arr = [[
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: 'Aceptar',
                callback_data: 'anunciar_cambio:confirmar'
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: 'Rechazar',
                callback_data: 'anunciar_cambio:rechazar'
            )
        ]]

        # Mando el tablero para aceptar o rechazarlo
        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        tablero = @tg.send_message(
            chat_id: @canal,
            reply_markup: opciones,
            parse_mode: :html,
            text: '¿Enviar el anuncio de la nueva versión '\
                  "#{versión_nueva} (la actual es #{versión_antigua})? "\
                  'Si aparece una versión más reciente antes de resolver este tablero '\
                  'se aceptará/resolverá esa última y no la que se especifica en '\
                  'este mensaje.'
        )

        return unless tablero && tablero['ok']

        @redis.set('versión:versión_tablero_anuncio', versión_nueva)
        @redis.set(
            'versión:id_tablero_anuncio',
            Telegram::Bot::Types::Message.new(tablero['result']).message_id
        )
    end
end
