class Dankie
    TIPOS_DE_MATCH = { substr: 'Texto parcial',
                       full: 'Coincidencia completa',
                       regexp: 'Expresión regular' }.freeze

    add_handler Handler::Mensaje.new(
        :cambiar_rep,
        tipos: [:text],
        ignorar_comandos: true,
        chats_permitidos: %i[group supergroup]
    )
    add_handler Handler::Comando.new(
        :rep,
        :enviar_ranking_rep,
        chats_permitidos: %i[group supergroup],
        descripción: 'Muestro el ranking de de reputación'
    )

    # Añadir disparador
    add_handler Handler::Comando.new(
        :crear_disparador,
        :enviar_botonera_crear_disparador,
        chats_permitidos: %i[group supergroup],
        descripción: 'Cargo un disparador de reputación nuevo'
    )
    add_handler Handler::CallbackQuery.new(
        :botonera_crear_disparador,
        'rep_crear_disparador'
    )
    add_handler Handler::Mensaje.new(
        :añadir_disparador,
        tipos: [:text],
        chats_permitidos: %i[group supergroup]
    )

    # Listar disparadores
    add_handler Handler::Comando.new(
        :disparadores,
        :enviar_lista_disparadores,
        chats_permitidos: %i[group supergroup],
        descripción: 'Te muestro la lista de disparadores de reputación.'
    )

    # Eliminar disparador
    add_handler Handler::Comando.new(
        :borrar_disparador,
        :borrar_disparador,
        permitir_params: true,
        chats_permitidos: %i[group supergroup],
        descripción: 'Elimino un disparador de reputación del grupo'
    )

    add_handler Handler::EventoDeChat.new(
        :reputación_supergrupo,
        tipos: [:migrate_from_chat_id],
        chats_permitidos: %i[supergroup]
    )

    def cambiar_rep(msj)
        # Δrep: 1  si max - min = 0
        #                                      |rep1 - min|
        #       (1 + log(1 + rep1 - rep2) ) * -------------- sí rep1 >= rep2
        #                                      |max - min|
        #
        #       |rep1 + (max - min)|
        #       --------------------    si rep1 < rep2
        #       |rep2 + (max - min)|
        #
        #
        # donde max y min son los valores mayor y menor de reputación en el grupo,
        #       rep1 es el que cambia y
        #       rep2 es el que va a ser cambiado

        return unless msj.reply_to_message
        return if msj.from.id == msj.reply_to_message.from.id
        return unless validar_permiso_rep(msj.chat.id)
        return unless (cambio = validar_disparadores_rep msj)
        return unless chequear_antiflood_rep(msj.from.id, msj.chat.id, msj.date)

        # Veo si ya se tomaron reps en el grupo y busco el rango entre
        # la rep más baja y la más alta
        rango = calcular_rango(msj)
        # El mínimo incremento es 0,001
        delta_rep = calcular_delta_rep(rango, msj) * cambio

        @redis.zincrby(
            "rep:#{msj.chat.id}",
            delta_rep,
            msj.reply_to_message.from.id
        )

        enviar_mensaje_y_a_spam(
            chat_id: msj.chat.id,
            parse_mode: :html,
            text: crear_texto_msj(msj, delta_rep),
            disable_web_page_preview: true
        )
    end

    def enviar_ranking_rep(msj)
        reps = @redis.zrevrange("rep:#{msj.chat.id}", 0, -1,
                                with_scores: true).map do |usuario|
            [obtener_enlace_usuario(usuario.first, msj.chat.id), usuario.last]
        end

        if reps.empty?
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'Nadie tiene reputación. umu'
            )
            return
        end
        arr = armar_arreglo_rep(reps)
        opciones = armar_botonera 0, arr.size, msj.from.id

        respuesta = @tg.send_message(chat_id: msj.chat.id,
                                     parse_mode: :html,
                                     reply_markup: opciones,
                                     text: arr.first,
                                     disable_web_page_preview: true,
                                     disable_notification: true)
        return unless respuesta && respuesta['ok']

        armar_lista(msj.chat.id,
                    Telegram::Bot::Types::Message.new(respuesta['result']).message_id,
                    arr)
    end

    def enviar_botonera_crear_disparador(msj)
        return unless es_admin(msj.from.id, msj.chat.id, msj.message_id,
                               "Solo los admines pueden hacer eso, #{TROESMAS.sample}.")

        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new(
            inline_keyboard: [] << { más: '➕', menos: '➖' }.map do |cambio, texto|
                Telegram::Bot::Types::InlineKeyboardButton.new(
                    text: texto,
                    callback_data: "rep_crear_disparador:#{msj.from.id}:#{cambio}:"
                )
            end
        )

        @tg.send_message(
            chat_id: msj.chat.id,
            parse_mode: :html,
            text: '¿Querés añadir un disparador que aumente o baje la reputación?',
            reply_markup: opciones,
            reply_to_message_id: msj.message_id
        )
    end

    def botonera_crear_disparador(callback)
        match = callback.data.match(
            /rep_crear_disparador:(?<id_usuario>\d+):(?<cambio>[[:word:]]+):(?<tipo>\w*)/
        )
        id_usuario = match[:id_usuario].to_i
        id_chat = callback.message.chat.id
        id_mensaje = callback.message.message_id
        cambio = match[:cambio]
        tipo = match[:tipo]

        return unless id_usuario == callback.from.id

        texto = format("Cambio elegido: <b>%<cambio>s</b>\n",
                       cambio: cambio == 'más' ? 'positivo' : 'negativo')

        if tipo.empty?
            botonera_elegir_tipo_de_cambio(id_usuario, cambio,
                                           callback, texto)

            return
        end

        # Si explota al editar el mensaje dejarlo morir así no se edita la db al pedo
        @tg.edit_message_text(
            callback: callback,
            chat_id: id_chat,
            message_id: id_mensaje,
            parse_mode: :html,
            text: texto + "Tipo de match: <b>#{TIPOS_DE_MATCH[tipo.to_sym]}</b>\n" +
                  html_parser('Respondeme a este mensaje con el texto >w<')
        )

        @redis.mapped_hmset("disparador_temp:#{id_mensaje}",
                            id_usuario: id_usuario, cambio: cambio, tipo: tipo,
                            id_chat: id_chat)
        @redis.expire("disparador_temp:#{id_mensaje}", 172_800) # dos días en segundos
    end

    def añadir_disparador(msj)
        return unless msj.reply_to_message

        id_mensaje = msj.reply_to_message.message_id
        datos = @redis.hgetall("disparador_temp:#{id_mensaje}").transform_keys!(&:to_sym)
        return if datos.empty?

        return unless validaciones_añadir_disparador(msj, datos)

        clave = "disparadores:#{datos[:tipo]}:#{msj.chat.id}:#{datos[:cambio]}"
        @redis.sadd(clave, msj.text.downcase)
        @redis.del("disparador_temp:#{id_mensaje}")

        @tg.send_message(
            chat_id: msj.chat.id,
            reply_to_message_id: msj.message_id,
            text: 'Disparador agregado exitosamente. nwn'
        )
    end

    def enviar_lista_disparadores(msj)
        arr = []

        cargar_arreglo_lista_disparadores(arr, msj.chat.id)

        if arr.empty?
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'No hay disparadores umu, se usan los por defecto + y 👍'
            )
            return
        end

        opciones = armar_botonera 0, arr.size, msj.from.id

        respuesta = @tg.send_message(chat_id: msj.chat.id,
                                     parse_mode: :html,
                                     reply_markup: opciones,
                                     text: arr.first,
                                     disable_notification: true)
        return unless respuesta && respuesta['ok']

        armar_lista(msj.chat.id,
                    Telegram::Bot::Types::Message.new(respuesta['result']).message_id,
                    arr)
    end

    def borrar_disparador(msj, params)
        return unless es_admin(msj.from.id, msj.chat.id, msj.message_id,
                               "Solo los admines pueden hacer eso, #{TROESMAS.sample}.")

        unless params
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "Decime que disparador borro, #{TROESMAS.sample}. >:c"
            )
            return
        end

        tipo, cambio = tipo_de_disparador(msj.chat.id, params)

        clave = "disparadores:#{tipo}:#{msj.chat.id}:#{cambio}"
        @redis.srem(clave, params.downcase)

        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         text: 'Disparador eliminado')
    end

    def reputación_supergrupo(msj)
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'rep:')

        TIPOS_DE_MATCH.keys.map(&:to_s).product(%w[más menos]).each do |tipo, cambio|
            cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                      msj.chat.id,
                                      "disparadores:#{tipo}:",
                                      ":#{cambio}")
        end
    end

    private

    def validar_permiso_rep(chat_id)
        Configuración.redis ||= @redis
        puede = Configuración.config(chat_id, :admite_rep)
        puede.nil? ? true : puede.to_i.positive?
    end

    def validar_disparadores_rep(msj)
        clave = "disparadores:%<tipo>s:#{msj.chat.id}:%<cambio>s"
        texto = msj.text.downcase

        if @redis.smembers(format(clave, tipo: 'substr', cambio: 'más'))
                 .any? { |d| texto[d] }
            return 1
        end

        if @redis.smembers(format(clave, tipo: 'substr', cambio: 'menos'))
                 .any? { |d| texto[d] }
            return -1
        end

        disparadores_match_completo(clave, 'más', texto) ||
            disparadores_match_completo(clave, 'menos', texto) ||
            disparadores_regexp(clave, 'más', texto) ||
            disparadores_regexp(clave, 'menos', texto)
    end

    def disparadores_match_completo(clave, cambio, texto)
        match_completo = @redis.smembers(format(clave, tipo: 'full', cambio: cambio))

        if match_completo.empty?
            match_completo = cambio == 'más' ? %w[+ 👍] : %w[- 👎]
        end

        match_completo.each { |d| return cambio == 'más' ? 1 : -1 if texto == d }

        nil
    end

    def disparadores_regexp(clave, cambio, texto)
        @redis.smembers(format(clave, tipo: 'regexp', cambio: cambio)).each do |d|
            Timeout.timeout(0.05) do
                return cambio == 'más' ? 1 : -1 if /#{d}/i.match?(texto)
            rescue Timeout::Error
                # Borrar coso
            end
        end
        nil
    end

    def chequear_antiflood_rep(id_usuario, id_chat, hora)
        @rep_flood ||= {}
        @rep_flood[id_chat] ||= {}
        @rep_flood[id_chat][id_usuario] ||= []

        incremetar_arr_flood(@rep_flood[id_chat][id_usuario], hora)

        chequear_flood(@rep_flood[id_chat][id_usuario], 34)
    end

    def calcular_rango(msj)
        case @redis.zcard("rep:#{msj.chat.id}")
        when 0
            [0]
        when 1
            val = @redis.zrevrange("rep:#{msj.chat.id}", 0, 1, with_scores: true)
                        .first.last
            [val, 0]
        else
            max = @redis.zrevrange("rep:#{msj.chat.id}", 0, 0,
                                   with_scores: true).dig(0, 1)
            min = @redis.zrevrange("rep:#{msj.chat.id}", -1, -1,
                                   with_scores: true).dig(0, 1)
            [min, max]
        end
    end

    def calcular_delta_rep(rango, msj)
        return 1 if rango.max == rango.min

        rep1 = @redis.zscore("rep:#{msj.chat.id}", msj.from.id) || 0
        rep2 = @redis.zscore("rep:#{msj.chat.id}", msj.reply_to_message.from.id) || 0

        # Me aseguro de que rango tome 0 en caso de que rango no contemple 0
        # (es el caso donde un usuario no tiene reputación asignada y le asigna 0)
        rango << rep1 << rep2

        delta = if rep1 < rep2
                    delta_rep_cociente(rep1, rep2, rango)
                else
                    delta_rep_log(rep1, rep2, rango)
                end

        [delta, 0.001].max
    end

    def delta_rep_cociente(rep1, rep2, rango)
        ((rep1 - rango.min) / (rep2 - rango.min)).abs
    end

    def delta_rep_log(rep1, rep2, rango)
        (1 + Math.log(1 + rep1 - rep2)) *
            ((rep1 - rango.min) / (rango.max - rango.min)).abs
    end

    def crear_texto_msj(msj, delta_rep)
        rep1 = format(
            '<b>(%<rep>.3f)</b> ',
            rep: @redis.zscore("rep:#{msj.chat.id}", msj.from.id) || 0
        )

        rep2 = format(
            '<b>(%<rep>.3f)</b>',
            rep: @redis.zscore("rep:#{msj.chat.id}", msj.reply_to_message.from.id) || 0
        )

        diferencia = format(
            '<i>(%<rep>+.3f)</i>.',
            rep: delta_rep
        )

        usuario1 = obtener_enlace_usuario msj.from.id, msj.chat.id
        usuario2 = obtener_enlace_usuario(msj.reply_to_message.from.id, msj.chat.id)
        cambiado = delta_rep.positive? ? 'incrementado' : 'reducido'

        "El usuario #{usuario1} #{rep1} ha #{cambiado} la "\
        "reputación de #{usuario2} #{rep2} #{diferencia}"
    end

    def armar_arreglo_rep(reputaciones)
        título = "<b>Ranking de reputación del grupo</b>\n"

        arr = []

        agr_elemento = proc do |elemento|
            format("\n<code>%<rep>.3f</code> %<nombre>s",
                   rep: elemento.last,
                   nombre: elemento.first || '<i>Usuario eliminado</i>')
        end

        arreglo_tablero(
            arr: arr,
            título: título,
            contador: 0,
            max_cant: 30,
            max_tam: 1000,
            agr_elemento: agr_elemento,
            conjunto_iterable: reputaciones
        )

        arr
    end

    def arreglo_disparadores(id_chat, tipo)
        clave = "disparadores:%<tipo>s:#{id_chat}:%<signo>s"

        disparadores = %w[más menos].map do |signo|
            @redis.smembers(format(clave, tipo: tipo, signo: signo)).map do |disp|
                { signo: signo, texto: disp }
            end
        end

        disparadores.flatten
    end

    def botonera_elegir_tipo_de_cambio(id_usuario, cambio,
                                       callback, texto)

        opciones = Telegram::Bot::Types::InlineKeyboardMarkup.new(
            inline_keyboard: TIPOS_DE_MATCH.map do |t, nombre|
                [Telegram::Bot::Types::InlineKeyboardButton.new(
                    text: nombre,
                    callback_data:
                    "rep_crear_disparador:#{id_usuario}:#{cambio}:#{t}"
                )]
            end
        )

        # Si explota acá ignoro las excepciones total se termina la ejecución
        @tg.edit_message_text(
            callback: callback,
            chat_id: callback.message.chat.id,
            reply_markup: opciones,
            parse_mode: :html,
            message_id: callback.message.message_id,
            text: texto,
            ignorar_excepciones_telegram: true
        )
    end

    def validaciones_añadir_disparador(msj, datos)
        return false unless msj.from.id == datos[:id_usuario].to_i
        return false unless msj.chat.id == datos[:id_chat].to_i

        if tipo_de_disparador(msj.chat.id, msj.text.downcase)
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "Mhh parece que ya hay un disparador así, #{TROESMAS.sample}."
            )
            return false
        end

        if datos[:tipo] == 'regexp'
            begin
                /#{msj.text.downcase}/i
            rescue RegexpError, ArgumentError
                @tg.send_message(
                    chat_id: msj.chat.id,
                    reply_to_message_id: msj.message_id,
                    text: "Esa no es una expresión regular válida, #{TROESMAS.sample}."
                )
                return false
            end
        end

        true
    end

    def tipo_de_disparador(chat_id, nombre)
        TIPOS_DE_MATCH.keys.map(&:to_s).product(%w[más menos]).each do |tipo, cambio|
            if @redis.sismember("disparadores:#{tipo}:#{chat_id}:#{cambio}", nombre)
                return tipo, cambio
            end
        end

        nil
    end

    def cargar_arreglo_lista_disparadores(arr, chat_id)
        contador = 0

        TIPOS_DE_MATCH.keys.map(&:to_s).each do |tipo|
            contador = arreglo_tablero(
                arr: arr,
                título: "<b>Lista de disparadores del grupo</b>\n",
                contador: contador || 0,
                max_cant: 30,
                max_tam: 1000,
                inicio_en_subtítulo: true,
                agr_elemento: proc do |fila|
                    format(
                        "\n<b>%<sig>s</b> <code>%<texto>s</code>",
                        sig: fila[:signo] == 'más' ? '+' : '-',
                        texto: html_parser(fila[:texto])
                    )
                end,
                conjunto_iterable: arreglo_disparadores(chat_id, tipo),
                subtítulo: format("\n<b>%<sub>s:</b>",
                                  sub: { 'substr' => 'De texto parcial',
                                         'full' => 'Texto completo',
                                         'regexp' => 'Expresión regular' }[tipo])
            )
        end
    end
end
