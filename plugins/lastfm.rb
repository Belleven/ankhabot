class Dankie
    add_handler Handler::Comando.new(:guardarlastfm, :guardar_lastfm,
                                     permitir_params: true,
                                     descripción: 'Guardo tu usuario de Last.Fm '\
                                                  '(solo necesito tu usuario)')
    add_handler Handler::Comando.new(:verlastfm, :ver_lastfm,
                                     descripción: 'Devuelvo el usuario de Last.fm '\
                                                  'que haya a tu nombre')
    add_handler Handler::Comando.new(:borrarlastfm, :borrar_lastfm,
                                     descripción: 'Borra tu cuenta de Last.Fm')
    add_handler Handler::Comando.new(:escuchando, :escuchando,
                                     descripción: 'Devuelvo la canción más '\
                                                  'reciente que escuchaste')
    add_handler Handler::Comando.new(:recientes, :recientes,
                                     permitir_params: true,
                                     descripción: 'Devuelvo las últimas '\
                                                  'canciones que escuchaste. '\
                                                  'Pasame un número así te muestro '\
                                                  'más de 1 canción (máx 15).')

    def guardar_lastfm(msj, usuario)
        return if no_hay_usuario(msj, usuario) || !usuario_válido(msj, usuario)

        @redis.set("lastfm:#{msj.from.id}", usuario)
        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         text: "Listo #{TROESMAS.sample}. "\
                               'Tu usuario de Last.fm ahora '\
                               "es '#{usuario}'.")
    end

    def ver_lastfm(msj)
        if (usuario = @redis.get("lastfm:#{msj.from.id}"))
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'Por el momento, tu usuario de '\
                                   "Last.fm es '#{usuario}'.")
        else
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No tengo ningún usuario tuyo '\
                                   'de Last.fm')
        end
    end

    def borrar_lastfm(msj)
        if @redis.del("lastfm:#{msj.from.id}") >= 1
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Ya borré tu cuenta #{TROESMAS.sample}")
        else
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "No pude borrar nada #{TROESMAS.sample}, "\
                               'probablemente no guardaste ninguna cuenta')
        end
    end

    def recientes(msj, cantidad)
        # Me fijo si pasan un natural como parámetro, si no seteo 3
        cantidad = cantidad.nil? || !(nat = natural(cantidad)) ? 3 : nat
        # Si se pasa de 15 lo reduzco a ese valor
        cantidad = 15 if cantidad > 15

        # Tomo el usuario de last.fm, y termino si no tengo ninguno
        usuario = @redis.get("lastfm:#{msj.from.id}")
        return if no_hay_usuario(msj, usuario)

        # Loggeo
        @logger.info("Pidiendo la\\s #{cantidad} última\\s "\
                                  "pista\\s que escuchó #{usuario}")

        # Tomo la cantidad de temas que me piden, y si me llega un error termino
        ahora_escuchando = @lastFM.now_playing usuario, cantidad
        return unless validar_pistas(msj, ahora_escuchando)

        # Empiezo a escribir el texto de respuesta y seteo variables para iterar
        # en los temas que me llegan de last.fm
        texto = "Canciones recientes del usuario: \n\n"
        inicio = 0
        fin = cantidad - 1
        contador = 1

        # Me fijo si hay un tema que se esté escuchando actualmente
        if ahora_escuchando.first.key?('@attr') &&
           ahora_escuchando.first['@attr']['nowplaying']
            # Están escuchando un tema, lo agrego como caso especial
            texto << "<b>#{contador}.</b>"
            agregar_datos_pista(texto, ahora_escuchando.first,
                                t1_antes: ' ', t1_dsp: ' ',
                                t2_antes: '- <b>', t2_dsp: '</b> ',
                                t3_antes: '[', t3_dsp: ']', actual: true)
            # Tengo que ignorar el primer elemento
            inicio += 1
            contador += 1

            # Ahora me fijo si este tema aparece repetido porque es algo que
            # suele pasar: te mandan primero el tema que estás escuchando y
            # después en la segunda posición del arreglo el mismo tema pero
            # como si ya lo hubieras escuchado. Si la cantidad que se pide es
            # 1 entonces no hago nada.
            if cantidad > 1 && mismo_tema(ahora_escuchando.first, ahora_escuchando[1])
                # Tengo que ignorar el segundo elemento y llegar hasta el final
                inicio += 1
                fin += 1
            end
        end

        # Itero por el resto del arreglo, ya sin casos especiales
        (inicio..fin).each do |índice|
            # Registro el número y tomo el tema
            texto << "<b>#{contador}.</b>"
            contador += 1
            temazo = ahora_escuchando[índice]
            # Agrego los datazos al texto
            agregar_datos_pista(texto, temazo,
                                t1_antes: ' ', t1_dsp: ' ',
                                t2_antes: '- <b>', t2_dsp: '</b> ',
                                t3_antes: '[', t3_dsp: ']')
        end

        # Mando el mensaje
        @tg.send_message(chat_id: msj.chat.id,
                         parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         text: texto)
    end

    def escuchando(msj)
        usuario = @redis.get("lastfm:#{msj.from.id}")
        return if no_hay_usuario(msj, usuario)

        @logger.info("Pidiendo la pista que está escuchando #{usuario}")
        temazo = @lastFM.now_playing usuario, 1
        return unless validar_pistas(msj, temazo)

        texto = if temazo.first.key?('@attr') && temazo.first['@attr']['nowplaying']
                    "<b>#{usuario}</b> está escuchando este temón: \n"
                else
                    "<b>#{usuario}</b> estuvo escuchando este temón: \n"
                end

        agregar_datos_pista(texto, temazo.first,
                            t1_antes: '👤: ', t1_dsp: "\n",
                            t2_antes: '🎵: ', t2_dsp: "\n",
                            t3_antes: '💿: ', imagen: true)

        @tg.send_message(chat_id: msj.chat.id,
                         parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         text: texto)
    end

    private

    def no_hay_usuario(msj, usuario)
        if (hay = usuario.nil? || usuario.empty?)
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'Si no me pasás un usuario, '\
                                    "está jodida la cosa #{TROESMAS.sample}.")
        end
        hay
    end

    def validar_pistas(msj, arr)
        if arr.empty?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: 'No encontré ninguna canción '\
                                   "que hayas escuchado #{TROESMAS.sample}.")
            return false
        elsif arr.first == 'error'
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             reply_to_message_id: msj.message_id,
                             text: "Alto error #{TROESMAS.sample}."\
                                   "\n<b>#{html_parser(arr[1])}</b>")
            @logger.error('Error con las pistas de '\
                                       "Last.fm : <b>#{arr[1]}</b>")
            return false
        end
        true
    end

    def usuario_válido(msj, usuario)
        unless (válido = usuario.length <= 15 &&
                         usuario.match?(/^[a-zA-Z][\w|-]+$/))
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Pasame un usuario válido #{TROESMAS.sample}.")
        end
        válido
    end

    def agregar_datos_pista(texto, temazo, t1_antes: '', t1_dsp: '', t2_antes: '',
                            t2_dsp: '', t3_antes: '', t3_dsp: '', imagen: false,
                            actual: false)

        partes_obtenidas = 0

        if temazo['artist']['#text'] && !temazo['artist']['#text'].empty?
            texto << t1_antes + html_parser(temazo['artist']['#text']) + t1_dsp
            partes_obtenidas += 1
        end

        if temazo['name'] && !temazo['name'].empty?
            texto << t2_antes + html_parser(temazo['name']) + t2_dsp
            partes_obtenidas += 1
        end

        if temazo['album']['#text'] && !temazo['album']['#text'].empty?
            texto << t3_antes + html_parser(temazo['album']['#text']) + t3_dsp
            partes_obtenidas += 1

            if imagen
                texto << '<a href="'\
                         "#{html_parser(temazo['image'][2]['#text'])}\">\u200d</a>"
            end
        end

        if partes_obtenidas.zero?
            texto = 'No pude encontrar información de '\
                    "lo que estás escuchando #{TROESMAS.sample} :("
        else
            ahora = actual ? ' (ahora)' : ''
            texto << "#{ahora}\n"
        end
    end

    def mismo_tema(tema1, tema2)
        # Si vienen con ID me fijo que sea el mismo ID
        (!tema1['mbid'].empty? && !tema2['mbid'].empty? &&
         tema1['mbid'] == tema2['mbid']) ||
            # Si no, chequeo los demás atributos
            (tema1['mbid'].length.zero? && tema2['mbid'].length.zero? &&
             tema1['artist'] == tema2['artist'] &&
             tema1['album'] == tema2['album'] &&
             tema1['url'] == tema2['url'] &&
             tema1['name'] == tema2['name'] &&
             tema1['image'] == tema2['image'])
    end
end
