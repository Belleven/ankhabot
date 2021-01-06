class Dankie
    add_handler Handler::Comando.new(
        :changelogs,
        :changelogs,
        permitir_params: false,
        descripción: 'Changelogs del bot'
    )
    add_handler Handler::CallbackQuery.new(:callback_confirmar_anuncio_changelog,
                                           'anunciar_cambio')

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
    def conseguir_changelog_version_actual
        archivo = File.open(CHANGELOG, 'r') { |f| archivo = f.read }

        # Separa en un array los diferentes changelogs
        archivo.split(/\n\s*\n(?=Versión )/)[0]
    end

    def callback_confirmar_anuncio_changelog(callback)
        match = callback.data.match(/anunciar_cambio:(?<acción>.+)/)

        return unless dev_responde_callback(callback)

        # En caso que se acepte, se procede a anunciar a todos
        # los grupos el cambio de versión
        if match[:acción] == 'confirmar'
            anunciar(callback.from, callback.message.chat.id,
                     conseguir_changelog_version_actual)
            resultado = 'aceptado'
            # Actualizo la version de redis
            @redis.set('versión', VERSIÓN)
        else
            resultado = 'rechazado'
        end

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

    def confirmar_anuncio_changelog(version_nueva, version_actual)
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
        @tg.send_message(chat_id: @canal, parse_mode: :html,
                         text: '¿Aceptar enviar el anuncio de la nueva versión '\
                         "#{version_nueva} (la actual es #{version_actual})?",
                         reply_markup: opciones, disable_web_page_preview: true,
                         disable_notification: true)
    end
end
