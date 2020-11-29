class Dankie
    add_handler Handler::CallbackQuery.new(:editar_botonera_lista, 'lista')
    add_handler Handler::CallbackQuery.new(:acciones_inferiores_lista, 'opcioneslista')

    # Las siguientes funciones son para manejar
    # listas de n páginas de texto, media o caption
    def editar_botonera_lista(callback)
        match = callback.data.match(/lista:(?<id_usuario>\d+):(?<índice>\d+)/)

        id_usuario = match[:id_usuario]
        id_chat = callback.message.chat.id
        id_mensaje = callback.message.message_id
        índice = match[:índice].to_i

        valor = obtener_elemento_lista(id_chat, id_mensaje, índice)
        metadatos = obtener_metadatos_lista(id_chat, id_mensaje)

        chequeos = cumple_chequeos_botonera_lista(
            valor,
            metadatos,
            índice,
            callback,
            id_usuario.to_i
        )
        return unless chequeos

        opciones = armar_botonera(
            índice,
            obtener_tamaño_lista(id_chat, id_mensaje),
            id_usuario,
            editable: metadatos[:editable_por] == 'todos'
        )

        editar_según_el_tipo(metadatos, id_chat, id_mensaje, valor, opciones)

        @redis.hset(
            "botonera:#{id_chat}:#{id_mensaje}:metadatos",
            'índice',
            índice
        )
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error e.to_s, al_canal: true
    end

    def acciones_inferiores_lista(callback)
        match = callback.data.match(
            /opcioneslista:(?<id_usuario>\d+):(?<índice>\d+)(:(?<acción>\w+))?/
        )

        id_usuario = match[:id_usuario].to_i
        id_chat = callback.message.chat.id
        id_mensaje = callback.message.message_id
        índice = match[:índice].to_i

        edit = @redis.hget "botonera:#{id_chat}:#{id_mensaje}:metadatos", 'editable_por'
        return unless validar_acciones_inferiores_lista(edit, id_usuario,
                                                        callback, match)

        resolver_acción_inferior_lista(
            match: match,
            callback: callback,
            id_chat: id_chat,
            id_mensaje: id_mensaje,
            id_usuario: id_usuario,
            índice: índice
        )
    rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error e.to_s, al_canal: false
    end

    private

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

    def cumple_chequeos_botonera_lista(valor, metadatos, índice, callback, id_usuario)
        if valor.nil? || metadatos.nil?
            @tg.answer_callback_query(
                callback_query_id: callback.id,
                text: 'Gomenasai, esta lista ya no está habilitada, '\
                      'pedí una nueva oniisan.'
            )
            return false
        elsif índice == metadatos[:índice].to_i
            @tg.answer_callback_query(callback_query_id: callback.id)
            return false
        # valido id_usuario y que sea editable
        elsif id_usuario.to_i != callback.from.id && metadatos[:editable_por] == 'dueño'
            @tg.answer_callback_query(
                callback_query_id: callback.id,
                text: "Pedite tu propia lista, #{TROESMAS.sample}."
            )
            return false
        end
        true
    end

    def armar_botonera(página_actual, tamaño_máximo, id_usuario, editable: false)
        return nil if tamaño_máximo == 1

        página_actual = [página_actual, tamaño_máximo - 1].min # valido el rango

        arr = [[]]
        botones_abajo = crear_botones_abajo(editable, id_usuario, página_actual)

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

        botones = rellenar_botones(página_actual, tamaño_máximo)

        botones.each do |botón|
            arr.first << Telegram::Bot::Types::InlineKeyboardButton.new(
                text: botón.first,
                callback_data: "lista:#{id_usuario}:#{botón.last}"
            )
        end

        arr << botones_abajo
        Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: arr)
    end

    def editar_según_el_tipo(metadatos, id_chat, id_mensaje, valor, opciones)
        case metadatos[:tipo]
        when 'texto'
            @tg.edit_message_text(
                chat_id: id_chat,
                parse_mode: :html,
                message_id: id_mensaje,
                disable_web_page_preview: true,
                disable_notification: true,
                text: valor,
                reply_markup: opciones
            )
        when 'caption'
            @tg.edit_message_caption(
                chat_id: id_chat,
                message_id: id_mensaje,
                parse_mode: :html,
                caption: valor,
                reply_markup: opciones
            )
        else
            @tg.edit_message_media(
                chat_id: id_chat,
                message_id: id_mensaje,
                media: {
                    type: metadatos[:tipo],
                    media: valor
                }.to_json,
                reply_markup: opciones
            )
        end
    end

    def validar_acciones_inferiores_lista(edit, id_usuario, callback, match)
        id_chat = callback.message.chat.id
        id_mensaje = callback.message.message_id

        # qué pasa si el msj fue borrado? mmm
        if edit.nil? || !@redis.exists?("botonera:#{id_chat}:#{id_mensaje}")
            @tg.answer_callback_query(
                callback_query_id: callback.id,
                text: 'Gomenasai, esta lista ya no está habilitada, '\
                      'pedí una nueva oniisan.'
            )
            return false
        # Esto es para cuando se aprieta el botón de candadito muy rápido antes
        # de que cambie la acción de la callback_data
        elsif (edit == 'dueño' && match[:acción] == 'noedit') ||
              (edit == 'todos' && match[:acción] == 'edit')
            @tg.answer_callback_query(callback_query_id: callback.id)
            return false
        # valido id_usuario y que sea editable
        elsif id_usuario != callback.from.id
            @tg.answer_callback_query(
                callback_query_id: callback.id,
                text: "Vos no podés hacer eso, #{TROESMAS.sample}."
            )
            return false
        end
        true
    end

    def resolver_acción_inferior_lista(params)
        callback = params[:callback]
        id_chat = params[:id_chat]
        id_mensaje = params[:id_mensaje]
        id_usuario = params[:id_usuario]
        índice = params[:índice]

        case params[:match][:acción]
        when 'borrar'
            @redis.del "botonera:#{id_chat}:#{id_mensaje}:metadatos"
            @redis.del "botonera:#{id_chat}:#{id_mensaje}"
            @tg.delete_message(chat_id: id_chat, message_id: id_mensaje)
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Mensaje borrado.')
        when 'edit'
            @redis.hset("botonera:#{id_chat}:#{id_mensaje}:metadatos",
                        'editable_por', 'todos')
            opciones = armar_botonera(índice, obtener_tamaño_lista(id_chat, id_mensaje),
                                      id_usuario, editable: true)
            @tg.edit_message_reply_markup(chat_id: id_chat, message_id: id_mensaje,
                                          reply_markup: opciones)
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Botonera ahora es presionable por todos.')
        when 'noedit'
            @redis.hset("botonera:#{id_chat}:#{id_mensaje}:metadatos",
                        'editable_por', 'dueño')
            opciones = armar_botonera(índice, obtener_tamaño_lista(id_chat, id_mensaje),
                                      id_usuario, editable: false)
            @tg.edit_message_reply_markup(chat_id: id_chat, message_id: id_mensaje,
                                          reply_markup: opciones)
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Botonera ahora solo es presionable '\
                                      'por el que la pidió.')
        end
    end

    def crear_botones_abajo(editable, id_usuario, página_actual)
        if editable
            emoji_editable = "\u{1F513}"
            acción = 'noedit'
        else
            emoji_editable = "\u{1F512}"
            acción = 'edit'
        end

        [
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: emoji_editable,
                callback_data: "opcioneslista:#{id_usuario}:#{página_actual}:#{acción}"
            ),
            Telegram::Bot::Types::InlineKeyboardButton.new(
                text: "\u274C",
                callback_data: "opcioneslista:#{id_usuario}:#{página_actual}:borrar"
            )
        ]
    end

    def rellenar_botones(página_actual, tamaño_máximo)
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
        botones
    end

    # Guarda el arreglo en redis, tipo puede valer 'texto', 'photo', 'video',
    # 'animation', 'audio', 'document' o 'caption'
    # editable puede valer 'dueño' o 'todos'. son los que pueden tocar los  botones
    def armar_lista(id_chat, id_msj, arreglo, tipo = 'texto', editable = 'dueño')
        return unless arreglo.length >= 2

        clave = "botonera:#{id_chat}:#{id_msj}"
        @redis.rpush clave, arreglo
        @redis.mapped_hmset "#{clave}:metadatos",
                            tipo: tipo, editable_por: editable, índice: 0
        # 86400 = 24*60*60 -> un día en segundos
        @redis.expire clave, 86_400
        @redis.expire "#{clave}:metadatos", 86_400
    end
end
