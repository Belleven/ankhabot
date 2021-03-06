# Extension de dankie para manejar las poles
class Dankie
    add_handler Handler::EventoDeChat.new(
        :pole_supergrupo,
        tipos: [:migrate_from_chat_id],
        chats_permitidos: %i[supergroup]
    )

    add_handler Handler::Mensaje.new(
        :pole,
        chats_permitidos: %i[group supergroup]
    )

    add_handler Handler::EventoDeChat.new(
        :pole,
        chats_permitidos: %i[group supergroup]
    )

    add_handler Handler::Comando.new(
        :nisman,
        :enviar_ranking_pole,
        chats_permitidos: %i[group supergroup],
        descripción: 'Muestro el ranking de Nisman'
    )

    def pole(msj)
        return unless validar_permiso_pole(msj.chat.id)

        id_chat = msj.chat.id
        id_usuario = msj.from.id

        @pole_flood ||= {}
        @pole_flood[id_chat] ||= {}
        @pole_flood[id_chat][id_usuario] ||= []

        incremetar_arr_flood(@pole_flood[id_chat][id_usuario], msj.date)

        # pole:chat_id:próxima es un timestamp de la hora de la próxima pole
        próx_pole = @redis.get("pole:#{id_chat}:próxima").to_i

        # Si la clave no existe, próx_pole vale 0 así que cuenta como hacer la pole
        return if próx_pole.to_i != 0 && msj.date < próx_pole

        return unless chequear_flood(@pole_flood[id_chat][id_usuario])

        calcular_nueva_pole_y_enviar(msj, id_chat, id_usuario)
    end

    def enviar_ranking_pole(msj)
        poles = @redis.zrevrange("pole:#{msj.chat.id}", 0, -1, with_scores: true)

        if poles.empty?
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'No hay poles en este grupo.',
                reply_to_message_id: msj.message_id
            )
            return
        end

        # Tomo el total de poles y lo agrego al título
        poles_totales = poles.map(&:last).inject { |c, i| c + i }

        arr = crear_arreglo_botonera(
            "<b>Ranking de Nisman</b> <i>(#{poles_totales.to_i})</i>\n",
            poles,
            msj
        )

        mandar_pole_y_crear_botonera(msj, arr)
    end

    # Para cuando un grupo se convierte en supergrupo
    def pole_supergrupo(msj)
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'pole:')
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'pole:',
                                  ':próxima')
    end

    private

    def validar_permiso_pole(chat_id)
        Configuración.redis ||= @redis
        puede = Configuración.config(chat_id, :admite_pole)
        puede.nil? ? true : puede.to_i.positive?
    end

    def mandar_pole_y_crear_botonera(msj, arr)
        respuesta = @tg.send_message(
            chat_id: msj.chat.id,
            text: arr.first,
            reply_markup: armar_botonera(0, arr.size, msj.from.id, editable: true),
            parse_mode: :html,
            reply_to_message_id: msj.message_id,
            disable_web_page_preview: true,
            disable_notification: true
        )
        return unless respuesta && respuesta['ok']

        respuesta = Telegram::Bot::Types::Message.new respuesta['result']
        armar_lista(msj.chat.id, respuesta.message_id, arr, 'texto', 'todos')
    end

    def crear_arreglo_botonera(título, poles, msj)
        arr = [título.dup]

        dígitos = poles.first[1].to_i.digits.count
        contador = 0

        poles.each do |pole|
            if contador == 31 || arr.last.size >= 2000
                arr << título.dup
                contador = 0
            end

            enlace_usuario = obtener_enlace_usuario(pole.first, msj.chat.id)

            arr.last << "\n<code>#{format("%#{dígitos}d", pole[1].to_i)}</code> "
            arr.last << (enlace_usuario || '<i>Usuario eliminado</i>')
            contador += 1
        end
        arr
    end

    def enviar_captura_pole(msj, id_chat, id_usuario)
        hoy = Time.at(msj.date)
        case [hoy.month, hoy.day]
        when [12, 25] # Navidad
            @redis.zincrby("pole:#{id_chat}", 5, id_usuario)
            tipo_de_pole = 'nisman navideña, +5'
        when [1, 1] # Año nuevo
            @redis.zincrby("pole:#{id_chat}", 2, id_usuario)
            tipo_de_pole = 'primer nisman del año, +2'
        else # Despues se podría añadir otro tipo de eventos, ej cumpleaños
            @redis.zincrby("pole:#{id_chat}", 1, id_usuario)
            tipo_de_pole = 'nisman'
        end

        nombre = if msj.from.first_name.empty?
                     "ay no c (#{id_usuario})"
                 else
                     html_parser(msj.from.first_name)
                 end

        @logger.info("#{nombre} hizo la nisman en #{id_chat}", al_canal: false)
        @tg.send_message(
            chat_id: id_chat,
            parse_mode: :html,
            reply_to_message_id: msj.message_id,
            text: "<b>#{nombre}</b> hizo la #{tipo_de_pole}."
        )
    end

    def calcular_nueva_pole_y_enviar(msj, id_chat, id_usuario)
        # Tomo el datetime del mensaje polero y le sumo 1 día
        # 86400 es un día en segundos -> 24*60*60 = 86400
        mañana = (Time.at msj.date, in: @tz.utc_offset) + 86_400
        # La próxima pole va a ser en el día de "mañana" pero a las 00:00:00
        próx_pole = Time.new(mañana.year, mañana.month, mañana.day,
                             0, 0, 0, @tz.utc_offset)

        @redis.set "pole:#{id_chat}:próxima", próx_pole.to_i

        enviar_captura_pole(msj, id_chat, id_usuario)
    end
end
