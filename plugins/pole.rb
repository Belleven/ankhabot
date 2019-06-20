# Extension de dankie para manejar las poles
class Dankie
    add_handler MessageHandler.new(:pole, allowed_chats: %i[group supergroup])
    add_handler CommandHandler.new(:nisman, :enviar_ranking_pole,
                                   description: 'Muestra el ranking de Nisman')

    # TODO: Ponerle algún flag de solo test a este comando
    # add_handler CommandHandler.new(:darnisman, :_test_dar_nisman)
    # add_handler CommandHandler.new(:borrar_clave_nisman, :_test_borrar_clave_nisman)

    # Variables para sincronizar y controlar la cantidad de threads que hay activos
    $nisman_activas = Concurrent::AtomicFixnum.new(0)
    $semáforo = Semáforo.new

    def _test_borrar_clave_nisman(msg)
        @redis.del("pole:#{msg.chat.id}:done")
        @tg.send_message(chat_id: msg.chat.id, text: 'Borré la clave pa')
    end

    def _test_dar_nisman(msg)
        id = msg.reply_to_message ? msg.reply_to_message.from.id : msg.from.id
        mensaje = msg.reply_to_message || msg

        nombre = mensaje.from.first_name.empty? ? msg.from.id.to_s : html_parser(mensaje.from.first_name)

        # Sincronizo para que se frene el comando /nisman hasta que se terminen de registrar la pole
        $semáforo.bloqueo_uno

        @redis.zincrby("pole:#{msg.chat.id}", 1, id)
        log(Logger::INFO, "#{nombre} hizo la nisman en #{msg.chat.id}", al_canal: false)
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{nombre}</b> hizo la Nisman")

        # No olvidarse de desbloquear el semáforo, esto es mucho muy importante
        $semáforo.desbloqueo_uno
    end

    def pole(msg)
        # pole:chat_id:next es un timestamp de la hora de la próxima pole
        próx_pole = @redis.get("pole:#{msg.chat.id}:próxima").to_i
        puts Time.at próx_pole, in: '-03:00'
        # Si la clave no existe, próx_pole vale 0 así que cuenta como hacer la pole
        return if próx_pole.to_i != 0 && msg.date <= próx_pole

        últ_pole = Time.at msg.date, in: '-03:00'
        próx_pole = Time.new(últ_pole.year, últ_pole.month, últ_pole.day + 1,
                             0, 0, 0, '-03:00')

        # Sincronizo para que se frene el comando /nisman hasta que se terminen de registrar la pole
        $semáforo.bloqueo_uno

        @redis.set "pole:#{msg.chat.id}:próxima", próx_pole.to_i
        @redis.zincrby("pole:#{msg.chat.id}", 1, msg.from.id)
        @redis.bgsave

        nombre = msg.from.first_name.empty? ? "ay no c (#{msg.from.id})" : html_parser(msg.from.first_name)

        log(Logger::INFO, "#{nombre} hizo la nisman en #{msg.chat.id}", al_canal: false)
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message_id: msg.message_id,
                         text: "<b>#{nombre}</b> hizo la Nisman")

        # No olvidarse de desbloquear el semáforo, esto es mucho muy importante
        $semáforo.desbloqueo_uno
    end

    def enviar_ranking_pole(msg)
        # Si hay 4 hilos activos entonces no atiendo el comando y aviso de esto
        if $nisman_activas.value >= 4
            # Problema improbable que NO puede notar el usuario y por eso no es importante arreglar:
            # Puede pasar durante el chequeo de este if, si pasa lo siguiente:
            # - El hilo principal toma el valor de "nisman_activas" de memoria que es 4
            # - Hay un cambio de contexto
            # - Uno o más hilos terminan y decrementan el valor de "nisman_activas" que ahora es 3 o menos
            # Debería poder crearse un nuevo hilo entonces
            # - PERO el durante el if se trajo un 4 de memoria, con lo cual va a devolver true la comparación 4 >= 4
            # - NO se va a crear un nuevo hilo cuando debería
            @tg.send_message(chat_id: msg.chat.id, reply_to_message_id: msg.message_id,
                             text: 'Disculpame pero hay demasiados comandos /nisman activos en este momento, acá y/o en otros grupetes. Vas a tener que esperar.')

        else

            texto = '<b>Ranking de Nisman</b>'
            enviado = @tg.send_message(chat_id: msg.chat.id,
                                       parse_mode: 'html',
                                       text: texto + "\n\n<i>cargando...</i>")
            enviado = Telegram::Bot::Types::Message.new(enviado['result'])

            # Aumento en 1 la cantidad de hilos activos
            $nisman_activas.increment

            # En vez de esto debería tener otra lista de plugins pesados que trabajen en un hilo aparte
            # --comentario de galera: mmmmm vs dcis? por ahora no hay otros comandos pesados, igual
            # es mucho más fácil sincronizar 2 hilos en vez de hasta 5

            Thread.new do
                # Sincronizo para que se frene la captura de la pole hasta que se terminen de mandar los rankings que fueron llamados
                $semáforo.bloqueo_muchos

                log(Logger::INFO, "#{msg.from.id} pidió el ranking de nisman en el chat #{msg.chat.id}", al_canal: false)

                editar_ranking_pole(enviado, texto)

                # No olvidarse de desbloquear el semáforo, esto es mucho muy importante
                $semáforo.desbloqueo_muchos
                # Además de habilitar un nuevo hilo
                $nisman_activas.decrement

                # Posible problema: después de esta instrucción podría haber un cambio de contexto antes de que muera el hilo??
                # Espero que no, porque si fuese así entonces podría haber más de 4 hilos del comando "/nisman" activos a la vez
                # Aunque eso no se va a notar en las variables, ni lo va a notar el usuario, pero en un caso super borde podría causar
                # problemas de eficiencia.
            end

        end
    end

    def editar_ranking_pole(enviado, texto)
        # Tomo las poles de las bases de datos y seteo los espacios para dígitos
        poles = @redis.zrevrange("pole:#{enviado.chat.id}", 0, -1, with_scores: true)
        dígitos = poles.first[1].to_i.digits.count

        # Tomo el total de poles y lo agrego al título
        texto << " (#{calcular_total_poles(poles)})\n"

        # Tomo otras variables que luego usaré
        chat_id = enviado.chat.id
        índice = 0

        poles.each do |pole|
            # Armo la línea y el cargando... si es que no es la última línea
            línea = "\n<code>#{format("%#{dígitos}d", pole[1].to_i)}</code> "
            línea << get_username_link(enviado.chat.id, pole[0])

            cargando = índice == poles.length - 1 ? '' : "\n<i>cargando...</i>"

            # Si el mensaje se pasa de los 4096 caracteres, mando uno nuevo
            if texto.length + línea.length + cargando.length > 4096

                # Primero borro el "cargando" del mensaje anterior
                @tg.edit_message_text(chat_id: chat_id, text: texto,
                                      parse_mode: 'html',
                                      message_id: enviado.message_id,
                                      disable_web_page_preview: true,
                                      disable_notification: true)

                # Después mando el nuevo mensaje
                texto = línea
                enviado = @tg.send_message(chat_id: chat_id, text: texto + cargando,
                                           parse_mode: 'html',
                                           disable_web_page_preview: true,
                                           disable_notification: true)
                enviado = Telegram::Bot::Types::Message.new(enviado['result'])

            # Si no, edito el actual
            else
                texto << línea
                @tg.edit_message_text(chat_id: chat_id, text: texto + cargando,
                                      parse_mode: 'html',
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
