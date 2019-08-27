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

    # Variables para sincronizar y controlar la cantidad de threads que hay activos
    $nisman_activas = Concurrent::AtomicFixnum.new(0)
    $semáforo = Semáforo.new

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

        # Sincronizo para que se frene el comando /nisman hasta que
        # se terminen de registrar la pole
        $semáforo.bloqueo_uno

        @redis.zincrby("pole:#{mensaje.chat.id}", 1, id)
        @logger.info("#{nombre} hizo la nisman en #{mensaje.chat.id}", al_canal: false)
        @tg.send_message(chat_id: mensaje.chat.id,
                         parse_mode: :html,
                         reply_to_message_id: mensaje.message_id,
                         text: "<b>#{nombre}</b> hizo la Nisman")

        # No olvidarse de desbloquear el semáforo, esto es mucho muy importante
        $semáforo.desbloqueo_uno
    end

    def pole(msj)
        # pole:chat_id:next es un timestamp de la hora de la próxima pole
        próx_pole = @redis.get("pole:#{msj.chat.id}:próxima").to_i

        # Si la clave no existe, próx_pole vale 0 así que cuenta como hacer la pole
        return if próx_pole.to_i != 0 && msj.date < próx_pole

        # Tomo el datetime del mensaje polero y le sumo 1 día
        # 86400 es un día en segundos -> 24*60*60 = 86400
        mañana = (Time.at msj.date, in: @tz.utc_offset) + 86_400
        # La próxima pole va a ser en el día de "mañana" pero a las 00:00:00
        próx_pole = Time.new(mañana.year, mañana.month, mañana.day,
                             0, 0, 0, @tz.utc_offset)

        # Sincronizo para que se frene el comando /nisman hasta que se
        # terminen de registrar la pole
        $semáforo.bloqueo_uno

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

        # No olvidarse de desbloquear el semáforo, esto es mucho muy importante
        $semáforo.desbloqueo_uno
    end

    def enviar_ranking_pole(msj)
        id_chat = msj.chat.id

        # Si hay 4 hilos activos entonces no atiendo el comando y aviso de esto
        if $nisman_activas.value >= 4
            # Problema improbable que NO puede notar el usuario y por eso no
            # es importante arreglar:
            # Puede pasar durante el chequeo de este if, si pasa lo siguiente:
            # - El hilo principal toma el valor de "nisman_activas" de memoria que es 4
            # - Hay un cambio de contexto
            # - Uno o más hilos terminan y decrementan el valor de "nisman_activas"
            #   que ahora es 3 o menos
            # Debería poder crearse un nuevo hilo entonces
            # - PERO durante el if se trajo un 4 de memoria, con lo cual va a devolver
            #   true la comparación 4 >= 4
            # - NO se va a crear un nuevo hilo cuando debería
            @tg.send_message(chat_id: id_chat,
                             reply_to_message_id: msj.message_id,
                             text: 'Disculpame pero hay demasiados comandos nisman '\
                                   'activos en este momento, acá y/o en otros '\
                                   'grupetes. Vas a tener que esperar.')

        else

            texto = '<b>Ranking de Nisman</b>'
            enviado = @tg.send_message(chat_id: id_chat,
                                       parse_mode: :html,
                                       text: texto + "\n\n<i>cargando...</i>")
            enviado = Telegram::Bot::Types::Message.new(enviado['result'])

            # Aumento en 1 la cantidad de hilos activos
            $nisman_activas.increment

            # En vez de esto debería tener otra lista de plugins pesados que trabajen
            # en un hilo aparte

            Thread.new do
                # Sincronizo para que se frene la captura de la pole hasta
                # que se terminen de mandar los rankings que fueron llamados
                $semáforo.bloqueo_muchos

                @logger.info("#{msj.from.id} pidió el ranking de nisman "\
                             "en el chat #{msj.chat.id}",
                             al_canal: false)

                editar_ranking_pole(enviado, texto)

                # No olvidarse de desbloquear el semáforo, esto es mucho muy importante
                $semáforo.desbloqueo_muchos
                # Además de habilitar un nuevo hilo
                $nisman_activas.decrement

                # Posible problema: después de esta instrucción podría haber un cambio
                # de contexto antes de que muera el hilo?? Espero que no, porque si
                # fuese así entonces podría haber más de 4 hilos del comando "/nisman"
                # activos a la vez. Aunque eso no se va a notar en las variables, ni lo
                # va a notar el usuario, pero en un caso super borde podría causar
                # problemas de eficiencia.
            end

        end
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
            línea << obtener_enlace_usuario(enviado.chat.id, pole[0])

            cargando = índice == poles.length - 1 ? '' : "\n<i>cargando...</i>"

            # Si el mensaje se pasa de los 4096 caracteres, mando uno nuevo
            if texto.length + línea.length + cargando.length > 4096

                # Primero borro el "cargando" del mensaje anterior
                @tg.edit_message_text(chat_id: id_chat, text: texto,
                                      parse_mode: :html,
                                      message_id: enviado.message_id,
                                      disable_web_page_preview: true,
                                      disable_notification: true)

                # Después mando el nuevo mensaje
                texto = línea
                enviado = @tg.send_message(chat_id: id_chat, text: texto + cargando,
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

            índice += 1
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
