class Dankie
    # Esto es como dankie_auxiliares pero con métodos auxiliares para botoneras

    private

    ADVERTENCIA_NSFW = 'AgACAgQAAx0CSSYxEwABET8GX8BG8iQwKpLZgwGLfJrVY-jQkJ4AAgmrMRujPB'\
                       'RQwRf4FTTSWGm-q3ojXQADAQADAgADeAADdkMDAAEeBA'.freeze

    def arreglo_tablero(params)
        conjunto_iterable = params[:conjunto_iterable]
        arr = params[:arr]
        subtítulo = params[:subtítulo]
        contador = params[:contador]
        max_cant = params[:max_cant]
        max_tam = params[:max_tam]

        return if conjunto_iterable.nil? || conjunto_iterable.empty?

        agregar_subtítulo(params)

        # Itero sobre los elementos
        conjunto_iterable.each do |elemento|
            # Si es una página nueva agrego título y subtítulo
            if arr.empty? || contador >= max_cant || arr.last.size >= max_tam
                arr << params[:título].dup
                arr.last << subtítulo.dup if subtítulo
                contador = 0
            end
            # Agrego el elemento juju
            arr.last << params[:agr_elemento].call(elemento)
            contador += 1
        end
        # Devuelvo el contador para que pueda ser usado luego en futuras
        # llamadas a esta función, recordar que los integers se pasan por
        # copia
        contador
    end

    def agregar_subtítulo(params)
        if params[:inicio_en_subtítulo] && !params[:arr].empty? && params[:subtítulo] &&
           params[:contador] < params[:max_cant] &&
           params[:arr].last.size < params[:max_tam]
            # Meto subtítulo si queda bien ponerlo en este caso
            params[:arr].last << "\n#{params[:subtítulo].dup}"
        end
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
                                   photo: ADVERTENCIA_NSFW,
                                   reply_markup: botones)
        return false unless respuesta

        respuesta = Telegram::Bot::Types::Message.new respuesta['result']

        respuesta.message_id
    end
end
