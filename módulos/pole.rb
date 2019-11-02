# Extension de dankie para manejar las poles
class Dankie
    add_handler Handler::EventoDeChat.new(:pole_supergrupo,
                                          tipos: [:migrate_from_chat_id],
                                          chats_permitidos: %i[supergroup])

    add_handler Handler::Mensaje.new(:pole, chats_permitidos: %i[group supergroup])
    add_handler Handler::EventoDeChat.new(:pole, chats_permitidos: %i[group supergroup])
    add_handler Handler::Comando.new(:nisman, :enviar_ranking_pole,
                                     chats_permitidos: %i[group supergroup],
                                     descripción: 'Muestro el ranking de Nisman')

    # TODO: Ponerle algún flag de solo test a este comando
    # add_handler Handler::Comando.new(:dar_nisman, :_test_dar_pole)
    # add_handler Handler::Comando.new(:reiniciar_nisman, :_test_reiniciar_pole)

    def _test_reiniciar_pole(msj)
        @redis.set "pole:#{msj.chat.id}:próxima", msg.date
        @tg.send_message(chat_id: msj.chat.id, text: 'Borré la clave pa')
    end

    def _test_dar_pole(msj)
        id = msj.reply_to_message ? msj.reply_to_message.from.id : msj.from.id
        mensaje = msj.reply_to_message || msj

        nombre = if mensaje.from.first_name.empty?
                     mensaje.from.id.to_s
                 else
                     html_parser(mensaje.from.first_name)
                 end

        @redis.zincrby("pole:#{mensaje.chat.id}", 1, id)
        @logger.info("#{nombre} hizo la nisman en #{mensaje.chat.id}", al_canal: false)
        @tg.send_message(chat_id: mensaje.chat.id,
                         parse_mode: :html,
                         reply_to_message_id: mensaje.message_id,
                         text: "<b>#{nombre}</b> hizo la Nisman")
    end

    def pole(msj)
        # pole:chat_id:próxima es un timestamp de la hora de la próxima pole
        próx_pole = @redis.get("pole:#{msj.chat.id}:próxima").to_i

        # Si la clave no existe, próx_pole vale 0 así que cuenta como hacer la pole
        return if próx_pole.to_i != 0 && msj.date < próx_pole

        # Tomo el datetime del mensaje polero y le sumo 1 día
        # 86400 es un día en segundos -> 24*60*60 = 86400
        mañana = (Time.at msj.date, in: @tz.utc_offset) + 86_400
        # La próxima pole va a ser en el día de "mañana" pero a las 00:00:00
        próx_pole = Time.new(mañana.year, mañana.month, mañana.day,
                             0, 0, 0, @tz.utc_offset)

        @redis.set "pole:#{msj.chat.id}:próxima", próx_pole.to_i
        @redis.zincrby("pole:#{msj.chat.id}", 1, msj.from.id)

        nombre = if msj.from.first_name.empty?
                     "ay no c (#{msj.from.id})"
                 else
                     html_parser(msj.from.first_name)
                 end

        @logger.info("#{nombre} hizo la nisman en #{msj.chat.id}", al_canal: false)
        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         text: "<b>#{nombre}</b> hizo la Nisman")
    end

    def enviar_ranking_pole(msj)
        poles = @redis.zrevrange("pole:#{msj.chat.id}", 0, -1, with_scores: true)

        if poles.nil?
            @tg.edit_message_text(chat_id: id_chat,
                                  text: 'No hay poles en este grupo.',
                                  message_id: enviado.message_id)
            return
        end

        título = '<b>Ranking de Nisman</b>'

        # Tomo el total de poles y lo agrego al título
        poles_totales = poles.map(&:last).inject { |c, i| c.to_i + i.to_i }
        título << " <i>(#{poles_totales})</i>\n"

        arr = [título.dup]

        dígitos = poles.first[1].to_i.digits.count
        contador = 0

        poles.each do |pole|
            if contador == 31 || arr.last.size >= 400
                arr << título.dup
                contador = 0
            end

            arr.last << "\n<code>#{format("%#{dígitos}d", pole[1].to_i)}</code> "
            arr.last << obtener_enlace_usuario(pole[0], msj.chat.id)

            contador += 1
        end

        # Armo botonera y envío
        opciones = armar_botonera 0, arr.size, msj.from.id, true

        respuesta = @tg.send_message(chat_id: msj.chat.id, text: arr.first,
                                     reply_markup: opciones, parse_mode: :html,
                                     reply_to_message_id: msj.message_id,
                                     disable_web_page_preview: true,
                                     disable_notification: true)
        return unless respuesta

        respuesta = Telegram::Bot::Types::Message.new respuesta['result']
        armar_lista(msj.chat.id, respuesta.message_id, arr, 'texto', 'todos')
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

    def editar_ranking_pole(enviado, texto)
        # Tomo las poles de las bases de datos y seteo los espacios para dígitos
        poles = @redis.zrevrange("pole:#{enviado.chat.id}", 0, -1, with_scores: true)
        id_chat = enviado.chat.id

        if poles.nil?
            @tg.edit_message_text(chat_id: id_chat,
                                  text: 'No hay poles en este grupo',
                                  message_id: enviado.message_id)
            return
        end

        dígitos = poles.first[1].to_i.digits.count

        # Tomo el total de poles y lo agrego al título
        texto << " (#{calcular_total_poles(poles)})\n"

        # Tomo otras variables que luego usaré
        índice = 0

        poles.each do |pole|
            # Armo la línea y el cargando... si es que no es la última línea
            línea = "\n<code>#{format("%#{dígitos}d", pole[1].to_i)}</code> "
            línea << obtener_enlace_usuario(pole.first, enviado.chat.id)

            cargando = índice == poles.length - 1 ? '' : "\n<i>cargando...</i>"
            índice += 1

            # Si el mensaje se pasa de los 4096 caracteres,
            # o ya hay más de 30 usuarios, mando uno nuevo
            if texto.length + línea.length + cargando.length > 4096 ||
               (índice % 30).zero?

                # Primero borro el "cargando" del mensaje anterior
                @tg.edit_message_text(chat_id: id_chat, text: texto,
                                      parse_mode: :html,
                                      message_id: enviado.message_id,
                                      disable_web_page_preview: true,
                                      disable_notification: true)

                # Después mando el nuevo mensaje
                texto = línea
                enviado = @tg.send_message(chat_id: id_chat, text: texto + cargando,
                                           reply_to_message_id: enviado.message_id,
                                           parse_mode: :html,
                                           disable_web_page_preview: true,
                                           disable_notification: true)
                enviado = Telegram::Bot::Types::Message.new(enviado['result'])

            # Si no, edito el actual
            else
                texto << línea
                @tg.edit_message_text(chat_id: id_chat, text: texto + cargando,
                                      parse_mode: :html,
                                      message_id: enviado.message_id,
                                      disable_web_page_preview: true,
                                      disable_notification: true)
            end
        end
    end

    def calcular_total_poles(poles)
        acumulador = 0
        poles.each do |pole|
            acumulador += pole[1].to_i
        end
        acumulador
    end
end
