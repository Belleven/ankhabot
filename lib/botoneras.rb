class Dankie
    # Las siguientes 5 funciones son para manejar listas de n páginas de texto
    def editar_botonera_lista(callback)
        match = callback.data.match(/lista:(?<id_usuario>.*):(?<índice>.*)/)
        índice = match[:índice].to_i
        id_usuario = match[:id_usuario].to_i

        # valido id_usuario
        if id_usuario != callback.from.id
            @tg.answer_callback_query(callback_query_id: callback.id,
                                      text: 'Pedite tu propia lista, '\
                                            "#{TROESMAS.sample}.")
            return
        end

        # valido si existe la clave

        opciones = armar_botonera(índice, 
                                  obtener_tamaño_lista(callback.message.chat.id,
                                                       callback.message.message_id),
                                  callback.from.id)

        texto = obtener_elemento_lista(callback.message.chat.id,
                                       callback.message.message_id,
                                       índice)

        if texto.nil?
            @tg.answer_callback_query(callback_query_id: callback.id)
            @tg.edit_message_text(chat_id: callback.message.chat.id,
                                  message_id: callback.message.message_id,
                                  text: 'Gomenasai, esta lista es muy vieja, '\
                                        'pedí una lista nueva oniisan.')
            return
        end

        @tg.answer_callback_query(callback_query_id: callback.id)
        @tg.edit_message_text(chat_id: callback.message.chat.id,
                              parse_mode: :html,
                              message_id: callback.message.message_id,
                              text: texto,
                              reply_markup: opciones)

    rescue Telegram::Bot::Exceptions::ResponseError
        puts 'lol'
    end

    def armar_lista(id_chat, id_msj, arreglo)
        @redis.rpush "botonera:#{id_chat}:#{id_msj}", arreglo
        @redis.expire "botonera:#{id_chat}:#{id_msj}", 60*60*24 # un día
    end

    def obtener_elemento_lista(id_chat, id_msj, índice)
        @redis.lindex "botonera:#{id_chat}:#{id_msj}", índice
    end

    def obtener_tamaño_lista(id_chat, id_msj)
        @redis.llen "botonera:#{id_chat}:#{id_msj}"
    end

    def armar_botonera(página_actual, tamaño_máximo, id_usuario)
        return nil if tamaño_máximo == 1
        página_actual = [página_actual, tamaño_máximo - 1].min # valido el rango

        arr = [[]]

        if tamaño_máximo <= 5
            tamaño_máximo.times do |i|
                arr.first << Telegram::Bot::Types::InlineKeyboardButton.new(
                    text: página_actual == i ? "< #{i + 1} >" : (i + 1).to_s,
                    callback_data: "lista:#{id_usuario}:#{i}")
            end
            return Telegram::Bot::Types::InlineKeyboardMarkup.new inline_keyboard: arr
        end

        botones = []

        if página_actual < 3
            4.times do |i|
                botones << [página_actual == i ? "<#{i + 1}>" : (i + 1).to_s, i]
            end
            botones << ["#{tamaño_máximo} >>", tamaño_máximo - 1]
        elsif página_actual > (tamaño_máximo - 4)
            botones << ["<< 1", 0]
            ((tamaño_máximo-4)..(tamaño_máximo-1)).each do |i|
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
                callback_data: "lista:#{id_usuario}:#{botón.last}")
        end

        Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: arr)
    end
end
