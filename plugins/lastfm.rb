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
    add_handler Handler::Comando.new(:recientes, :recientes, permitir_params: true,
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
        cantidad = cantidad ? natural(cantidad) : 3

        if !cantidad
            cantidad = 3
        elsif cantidad > 15
            cantidad = 15
        end

        usuario = @redis.get("lastfm:#{msj.from.id}")
        return if no_hay_usuario(msj, usuario)

        @logger.info("Pidiendo la\\s #{cantidad} última\\s "\
                                  "pista\\s que escuchó #{usuario}")
        ahora_escuchando = @lastFM.now_playing usuario, cantidad
        return unless validar_pistas(msj, ahora_escuchando)

        texto = "Canciones recientes del usuario: \n\n"
        ahora_escuchando.each_with_index do |temazo, índice|
            texto << "<b>#{índice + 1}.</b>"
            agregar_datos_pista(texto, temazo, t1_antes: ' ', t1_dsp: ' ',
                                               t2_antes: '- <b>', t2_dsp: '</b> ', t3_antes: '[',
                                               t3_dsp: ']')
        end
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

        texto = "Mirate este temón: \n"
        agregar_datos_pista(texto, temazo.first, t1_antes: '👤: ', t1_dsp: "\n",
                                                 t2_antes: '🎵: ', t2_dsp: "\n", t3_antes: '💿: ',
                                                 imagen: true)

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
                            t2_dsp: '', t3_antes: '', t3_dsp: '', imagen: false)

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
                texto << "<a href=\"#{html_parser(temazo['image'][2]['#text'])}\">\u200d</a>"
            end
        end

        if partes_obtenidas == 0
            texto = 'No pude encontrar información de '\
                    "lo que estás escuchando #{TROESMAS.sample} :("
        else
            texto << "\n"
        end
    end
end
