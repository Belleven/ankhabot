class Dankie
    # Las siguientes i6 funciones son para manejar listas de n páginas de texto, media o caption
    def editar_botonera_lista(callback)
        match = callback.data.match(/lista:(?<id_usuario>\d+):(?<índice>\d+)/)

        id_usuario = match[:id_usuario].to_i
        id_chat = callback.message.chat.id
        id_mensaje = callback.message.message_id
        índice = match[:índice].to_i

        metadatos = obtener_metadatos_lista(id_chat, id_mensaje)

        # valido id_usuario y que sea editable
        if id_usuario != callback.from.id && metadatos[:editable_por] == 'dueño'
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Pedite tu propia lista, '\
                                            "#{TROESMAS.sample}.")
            return
        end

        opciones = armar_botonera(índice,
                                  obtener_tamaño_lista(id_chat, id_mensaje),
                                  id_usuario,
                                  metadatos[:editable_por] == 'todos')

        valor = obtener_elemento_lista(id_chat,
                                       id_mensaje,
                                       índice)

        @tg.answer_callback_query(callback_query_id: callback.id)

        if valor.nil?
            @tg.edit_message_text(chat_id: id_chat,
                                  message_id: id_mensaje,
                                  text: 'Gomenasai, esta lista es muy vieja, '\
                                        'pedí una lista nueva oniisan.')
            return
        end

        case metadatos[:tipo]
        when 'texto'
            @tg.edit_message_text(chat_id: id_chat,
                                  parse_mode: :html,
                                  message_id: id_mensaje,
                                  disable_web_page_preview: true,
                                  disable_notification: true, # TODO: ver como permitir que estos dos sean variables ???
                                  text: valor,
                                  reply_markup: opciones)
        when 'caption'
            @tg.edit_message_caption(chat_id: id_chat,
                                     message_id: id_mensaje,
                                     parse_mode: :html,
                                     caption: valor,
                                     reply_markup: opciones)
        else
            @tg.edit_message_media(chat_id: id_chat, message_id: id_mensaje,
                                   media: { type: metadatos[:tipo],
                                            media: valor }.to_json,
                                   reply_markup: opciones)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error e.to_s, al_canal: false
    end

    def acciones_inferiores_lista(callback)
        match = callback.data.match(
            /opcioneslista:(?<id_usuario>\d+):(?<índice>\d+)(:(?<acción>\w+))?/
        )

        id_usuario = match[:id_usuario].to_i
        id_chat = callback.message.chat.id
        id_mensaje = callback.message.message_id
        índice = match[:índice].to_i

        # valido id_usuario y que sea editable
        if id_usuario != callback.from.id
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Vos no podés hacer eso, '\
                                            "#{TROESMAS.sample}.")
            return
        end

        case match[:acción]
        when 'borrar'
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Mensaje borrado.')
            @tg.delete_message(chat_id: id_chat, message_id: id_mensaje)
        when 'edit'
            @redis.hset("botonera:#{id_chat}:#{id_mensaje}:metadatos",
                        'editable_por', 'todos')
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Botonera ahora es presionable por todos.')
            opciones = armar_botonera(índice, obtener_tamaño_lista(id_chat, id_mensaje),
                                      id_usuario, true)
            @tg.edit_message_reply_markup(chat_id: id_chat, message_id: id_mensaje,
                                          reply_markup: opciones)
        when 'noedit'
            @redis.hset("botonera:#{id_chat}:#{id_mensaje}:metadatos",
                        'editable_por', 'dueño')
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Botonera ahora solo es presionable '\
                                      'por el que la pidió.')
            opciones = armar_botonera(índice, obtener_tamaño_lista(id_chat, id_mensaje),
                                      id_usuario, false)
            @tg.edit_message_reply_markup(chat_id: id_chat, message_id: id_mensaje,
                                          reply_markup: opciones)
        end
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error e.to_s, al_canal: false
    end

    # Guarda el arreglo en redis, tipo puede valer 'texto', 'photo', 'video',
    # 'animation', 'audio', 'document' o 'caption'
    # editable puede valer 'dueño' o 'todos'. son los que pueden tocar los  botones
    def armar_lista(id_chat, id_msj, arreglo, tipo = 'texto', editable = 'dueño')
        clave = "botonera:#{id_chat}:#{id_msj}"
        @redis.rpush clave, arreglo
        @redis.mapped_hmset "#{clave}:metadatos", tipo: tipo, editable_por: editable
        # 86400 = 24*60*60 -> un día en segundos
        @redis.expire clave, 86_400
        @redis.expire "#{clave}:metadatos", 86_400
    end

    def obtener_elemento_lista(id_chat, id_msj, índice)
        @redis.lindex "botonera:#{id_chat}:#{id_msj}", índice
    end

    def obtener_tamaño_lista(id_chat, id_msj)
        @redis.llen "botonera:#{id_chat}:#{id_msj}"
    end

    def obtener_metadatos_lista(id_chat, id_msj)
        h = @redis.hgetall("botonera:#{id_chat}:#{id_msj}:metadatos")
        h.transform_keys!(&:to_sym)
    end

    def armar_botonera(página_actual, tamaño_máximo, id_usuario, editable = false)
        return nil if tamaño_máximo == 1

        página_actual = [página_actual, tamaño_máximo - 1].min # valido el rango

        arr = [[]]
        botones_abajo = [Telegram::Bot::Types::InlineKeyboardButton.new(
            text: (editable ? "\u{1F513}" : "\u{1F512}"),
            callback_data: "opcioneslista:#{id_usuario}:#{página_actual}:"\
                           "#{editable ? 'noedit' : 'edit'}"
        ),
                         Telegram::Bot::Types::InlineKeyboardButton.new(
                             text: "\u274C",
                             callback_data: "opcioneslista:#{id_usuario}:#{página_actual}:"\
                                            'borrar'
                         )]

        if tamaño_máximo <= 5
            tamaño_máximo.times do |i|
                arr.first << Telegram::Bot::Types::InlineKeyboardButton.new(
                    text: página_actual == i ? "< #{i + 1} >" : (i + 1).to_s,
                    callback_data: "lista:#{id_usuario}:#{i}"
                )
            end
            arr << botones_abajo
            return Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        end

        botones = []

        if página_actual < 3
            4.times do |i|
                botones << [página_actual == i ? "<#{i + 1}>" : (i + 1).to_s, i]
            end
            botones << ["#{tamaño_máximo} >>", tamaño_máximo - 1]
        elsif página_actual > (tamaño_máximo - 4)
            botones << ['<< 1', 0]
            ((tamaño_máximo - 4)..(tamaño_máximo - 1)).each do |i|
                botones << [página_actual == i ? "<#{i + 1}>" : (i + 1).to_s, i]
            end
        else
            botones << ['<< 1', 0]
            botones << ["< #{página_actual}", página_actual - 1]
            botones << ["< #{página_actual + 1} >", página_actual]
            botones << ["#{página_actual + 2} >", página_actual + 1]
            botones << ["#{tamaño_máximo} >>", tamaño_máximo - 1]
        end

        botones.each do |botón|
            arr.first << Telegram::Bot::Types::InlineKeyboardButton.new(
                text: botón.first,
                callback_data: "lista:#{id_usuario}:#{botón.last}"
            )
        end

        arr << botones_abajo
        Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: arr)
    end

    # Método que manda una botonera preguntando si se quiere enviar un nsfw.
    # Devuelve el id del mensaje, o false si no pudo enviar.
    # Uno tiene que hacer su propio handler con el prefijo pasado.
    def preguntar_nsfw(id_chat, id_usuario, prefijo_callback)
        arr = %w[Mostrar Borrar]
        arr.map! do |botón|
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: botón,
                callback_data: "#{prefijo_callback}:#{id_usuario}:#{botón}"
            )
        end

        botones = Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: [arr])
        respuesta = @tg.send_photo(chat_id: id_chat,
                                   caption: 'El contenido que querés ver es NSFW. '\
                                            '¿Ver de todas formas?',
                                   photo: 'AgADAQADKagxG1kzoEUdtJ7Xoasff832awYABAEAAwIAA3gAA10kAQABFgQ',
                                   reply_markup: botones)
        return false unless respuesta

        respuesta = Telegram::Bot::Types::Message.new respuesta['result']

        respuesta.message_id
    end
end
