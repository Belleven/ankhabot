require 'filesize'

class Dankie
    add_handler Handler::Comando.new(:metadatos,
                                     :metadatos,
                                     permitir_params: true,
                                     descripción: 'Muestro los metadatos del '\
                                                  'mensaje respondido')

    add_handler Handler::Comando.new(:contenido,
                                     :contenido,
                                     descripción: 'Muestro el contenido del '\
                                                  'mensaje respondido')

    add_handler Handler::Comando.new(:infomensaje,
                                     :info_mensaje,
                                     descripción: 'Muestro la información del '\
                                                  'mensaje respondido')

    def metadatos(msj, parámetros)
        # Si no responde a nada mando error
        if msj.reply_to_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Respondele a un mensaje #{TROESMAS.sample}")
        else
            # Me fijo si me piden que pase las entidades
            pasar_entidades = parámetros && parámetros.downcase == '-entidades'

            # De ser así reviso que haya sido un dev pues puede floodear violentamente
            # mostras las entidades de un mensaje
            if pasar_entidades && !DEVS.include?(msj.chat.id)
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: msj.message_id,
                                 text: 'Tenés que ser desarrollador '\
                                          "para eso #{TROESMAS.sample}")
                return
            end

            # Creo el texto que irá siendo modificado
            texto = "<b>Metadatos del mensaje:</b>\n"
            # Agrego los datos del mensaje
            agregar_datos_mensaje(msj.reply_to_message, texto, pasar_entidades, 0)

            # Mando el mensaje
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             text: texto,
                             disable_web_page_preview: true,
                             disable_notification: true)
        end
    end

    def contenido(msj)
        # Si no responde a nada mando error
        if msj.reply_to_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Respondele a un mensaje #{TROESMAS.sample}")
        else
            texto = '<b>Contenido del mensaje:</b>'
            agregar_contenido(texto, msj.reply_to_message, 1, false)
            # Mando el mensaje
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             text: texto,
                             disable_web_page_preview: true,
                             disable_notification: true)
        end
    end

    def info_mensaje(msj)
        # Si no responde a nada mando error
        if msj.reply_to_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Respondele a un mensaje #{TROESMAS.sample}")
        else
            texto = '<b>Info del mensaje:</b>'
            agregar_info_mensaje(msj.reply_to_message, texto, 0)
            # Mando el mensaje
            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             text: texto,
                             disable_web_page_preview: true,
                             disable_notification: true)
        end
    end

    private

    def agregar_datos_mensaje(msj, texto, pasar_entidades, nivel)
        # Agrego info del mensaje (usuario, chat, etc)
        agregar_info_mensaje(msj, texto, nivel)
        # Agrego contenido del mensaje (texto, imágenes, etc)
        agregar_contenido(texto, msj, nivel + 1, pasar_entidades)
    end

    def agregar_info_mensaje(msj, texto, nivel)
        # Pongo la id del mensaje
        texto << "\n- ID del mensaje:<code> #{msj.message_id}</code>"
        # Fecha del mensaje
        fecha = Time.at(msj.date, in: @tz.utc_offset).to_datetime
        texto << "\n- Fecha envío:<code> #{fecha.strftime('%d/%m/%Y %T %Z')}</code>"

        # Fecha de última edición del mensaje
        if msj.edit_date
            fecha_edición = Time.at(msj.edit_date, in: @tz.utc_offset).to_datetime
            fecha_edición = fecha_edición.strftime('%d/%m/%Y %T %Z')
            texto << "\n- Última edición:<code> #{fecha_edición}</code>"
        end

        # Si hay multimedia, mando el id de mensaje multimedia
        if msj.media_group_id
            texto << "\n - ID del mensaje multimedia:"\
                     "<code> #{msj.media_group_id}</code>"
        end

        # Si se conectó a un sitio
        if msj.connected_website
            texto << "\n - Sitio web conectado:"\
                     "<code> #{msj.connected_website}</code>"
        end

        # Si hay autor, lo agrego
        if msj.author_signature
            texto << "\n - Autor: "\
                     "#{html_parser(msj.author_signature)}"
        end

        # Agrego usuario
        if msj.from
            usuario = enlace_usuario_objeto(msj.from, msj.chat.id)
            título = "\n\n - Enviado por: #{usuario}"
            agregar_usuario(texto, msj.from, título, nivel + 1)
        end

        # Agrego chat
        agregar_chat(texto, msj.chat, "\n\n -Chat:", nivel + 1)
        # Agregar info reenvío
        agregar_info_reenvío(texto, msj, nivel + 1) if msj.forward_date
    end

    def agregar_usuario(texto, usuario, título, nivel)
        tab = crear_tab(nivel)

        # Agrego título, id y si es bot
        texto << "#{título}"\
                 "#{tab} ID:<code> #{usuario.id}</code>"\
                 "#{tab} Bot:<code> #{usuario.is_bot ? 'Sí' : 'No'}</code>"\

        # Me fijo si es cuenta eliminada, y si no, pongo 1er y 2do nombre, y alias
        texto << "#{tab} Cuenta Eliminada:"
        if usuario.first_name.empty?
            texto << '<code> Sí</code>'
        else
            texto << '<code> No</code>'
            agregar_nombres(texto, usuario, nivel)

            # Código de lenguaje si tiene
            if usuario.language_code
                texto << "#{tab} Código de lenguaje:"\
                         "<code> #{usuario.language_code}</code>"
            end
        end
    end

    def agregar_chat(texto, chat, título, nivel)
        tab = crear_tab(nivel)

        # Agrego id y tipo
        texto << "#{título}"\
                 "#{tab} ID:<code> #{chat.id}</code>"\
                 "#{tab} Tipo:<code> #{chat.type}</code>"

        # Agrego título si tiene, si no info del chat privado
        texto << "#{tab} Título:<code> #{html_parser(chat.title)}</code>" if chat.title
        # Agrego nombre, apellido y alias si hay
        agregar_nombres(texto, chat, nivel)
    end

    def agregar_nombres(texto, elemento, nivel)
        tab = crear_tab(nivel)

        # Pongo primer nombre
        if elemento.first_name
            texto << "#{tab} Nombre:<code> "\
                     "#{html_parser(elemento.first_name)}</code>"
        end

        # Segundo nombre si tiene
        if elemento.last_name
            texto << "#{tab} Apellido:<code> "\
                     "#{html_parser(elemento.last_name)}</code>"
        end

        # Alias si tiene
        alias_usuario = if elemento.username
                            "<code> #{elemento.username}</code>"
                        else
                            '  <i>No tiene</i>'
                        end
        texto << "#{tab} Alias:#{alias_usuario}"
    end

    def agregar_info_reenvío(texto, msj, nivel)
        tab = crear_tab(nivel)

        # Obtengo fecha
        fecha_reenvío = Time.at(msj.forward_date, in: @tz.utc_offset).to_datetime
        fecha_reenvío = fecha_reenvío.strftime('%d/%m/%Y %T %Z')

        # Pongo título y fecha original de envío
        texto << "\n\n- Información de reenvío:"\
                 "#{tab} Fecha envío original:<code> #{fecha_reenvío}</code>"

        # Info del usuario original
        if msj.forward_from
            texto << "#{tab} Cuenta oculta:<code> No</code>"
            usuario = enlace_usuario_objeto(msj.forward_from, msj.chat.id)
            título = "#{tab} Reenviado de: #{usuario}"
            agregar_usuario(texto, msj.forward_from, título, nivel + 1)
        elsif msj.forward_sender_name
            # Si es una cuenta oculta
            texto << "#{tab} Cuenta oculta:<code> Sí</code>"
            nombre = html_parser(msj.forward_sender_name)
            texto << "#{tab} Nombre:<code> #{nombre}</code>"
        elsif msj.forward_from_chat
            # Si es reenviado de un canal
            texto << "#{tab} Reenviado de un canal:<code> Sí</code>"\

            # Si tengo el id original del mensaje
            if msj.forward_from_message_id
                texto << "#{tab} ID mensaje original:<code> "\
                         "#{msj.forward_from_message_id}</code>"
            end

            # Si tengo la firma del mensaje
            if msj.forward_signature
                texto << "#{tab} Firma:<code> "\
                         "#{html_parser(msj.forward_signature)}</code>"
            end

            # Agrego información del Canal original
            título = "#{tab} Canal original del mensaje:"
            agregar_chat(texto, msj.forward_from_chat, título, nivel + 1)
        end
    end

    def agregar_contenido(respuesta, msj, nivel, pasar_entidades)
        # Agrego texto si hay
        agregar_texto(respuesta, 'Texto:', msj.text, msj.entities,
                      nivel, pasar_entidades)

        # Otros
        if !msj.photo.empty?
            agregar_imágenes(respuesta, msj.photo, "\n\n - Imagen:", nivel)
        elsif msj.animation
            agregar_animación(respuesta, msj.animation, "\n\n - Gif:", nivel)
        elsif msj.sticker
            agregar_sticker(respuesta, msj.sticker, nivel)
        elsif msj.audio
            agregar_audio(respuesta, msj.audio, nivel)
        elsif msj.voice
            agregar_msj_voz(respuesta, msj.voice, nivel)
        elsif msj.video
            agregar_video(respuesta, msj.video, nivel)
        elsif msj.video_note
            agregar_nota_video(respuesta, msj.video_note, nivel)
        elsif msj.document
            agregar_documento(respuesta, msj.document, nivel)
        elsif msj.poll
            agregar_encuesta(respuesta, msj.poll, nivel)
        elsif msj.location
            agregar_ubicación(respuesta, msj.location, "\n\n - Ubicación:", nivel)
        elsif msj.contact
            agregar_contacto(respuesta, msj.contact, nivel)
        elsif msj.game
            agregar_juego(respuesta, msj.game, nivel, pasar_entidades)
        elsif msj.reply_markup
            agregar_botones(respuesta, msj.reply_markup, nivel)
        elsif msj.venue
            agregar_venue(respuesta, msj.venue, nivel)
        elsif msj.passport_data
            agregar_pasaporte(respuesta, msj.passport_data, nivel)
        elsif msj.successful_payment
            agregar_pago(respuesta, msj.successful_payment, nivel)
        else
            agregar_eventos_chat(respuesta, msj, nivel)
        end

        # Agrego caption si hay
        agregar_texto(respuesta, 'Epígrafe:', msj.caption, msj.caption_entities,
                      nivel, pasar_entidades)
    end

    def agregar_texto(respuesta, título, texto_msj, entidades, nivel, pasar_entidades)
        return unless texto_msj

        long = texto_msj.length

        # Agrego el texto
        texto_msj = (texto_msj[0..200] + '...') if long > 200
        respuesta << "\n\n - #{título}<code> #{html_parser(texto_msj)}</code>"
        respuesta << "\n - Longitud:<code> #{long}</code>"

        # Agrego las entidades
        respuesta << "\n - Entidades del #{título.downcase}"\
                     "<code> #{entidades.length}</code>"

        return if entidades.empty? || !pasar_entidades

        # Creo tabs
        tab1 = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)

        entidades.each_with_index do |entidad, índice|
            # Nro entidad
            respuesta << "#{tab1} Entidad <b>#{índice + 1}</b>:"\
                        "#{tab2} Tipo:<code> #{entidad.type}</code>"\
                        "#{tab2} Desfasaje:<code> #{entidad.offset}</code>"\
                        "#{tab2} Longitud:<code> #{entidad.length}</code>"

            if entidad.url
                respuesta << "#{tab2} Enlace:"\
                         "<code> #{html_parser(entidad.url)}</code>"
            end

            next unless entidad.user

            título = "#{tab2} Usuario mencionado:"
            agregar_usuario(respuesta, entidad.user, título, nivel + 2)
        end
    end

    def agregar_audio(texto, audio, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Audio:"\
                 "#{tab} ID:<code> #{audio.file_id}</code>"\
                 "#{tab} Duración:<code> #{duracion_entera(audio.duration)}</code>"

        # Agrego datos opcionales
        if audio.performer
            texto << "#{tab} Artista:<code> "\
                     "#{html_parser(audio.performer)}</code>"
        end
        if audio.title
            texto << "#{tab} Título:<code> "\
                     "#{html_parser(audio.title)}</code>"
        end
        texto << "#{tab} MIME:<code> #{audio.mime_type}</code>" if audio.mime_type

        # Agrego tamaño
        tamaño = Filesize.from("#{audio.file_size} B").pretty
        texto << "#{tab} Tamaño:<code> #{tamaño}</code>" if audio.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, audio.thumb, nivel, 'Miniatura') if audio.thumb
    end

    def agregar_documento(texto, doc, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Documento:"\
                 "#{tab} ID:<code> #{doc.file_id}</code>"

        # Agrego datos opcionales
        if doc.file_name
            texto << "#{tab} Nombre:<code> "\
                     "#{html_parser(doc.file_name)}</code>"
        end
        texto << "#{tab} MIME:<code> #{doc.mime_type}</code>" if doc.mime_type

        # Agrego tamaño
        tamaño = Filesize.from("#{doc.file_size} B").pretty
        texto << "#{tab} Tamaño:<code> #{tamaño}</code>" if doc.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, doc.thumb, nivel, 'Miniatura') if doc.thumb
    end

    def agregar_animación(texto, animación, título, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "#{título}"\
                 "#{tab} ID:<code> #{animación.file_id}</code>"

        # Agrego datos opcionales
        if animación.respond_to?(:duration) && animación.duration
            duración = duracion_entera(animación.duration)
            texto << "#{tab} Duración:<code> #{duración}</code>"
        end

        if animación.respond_to?(:width) && animación.width
            texto << "#{tab} Ancho:<code> #{animación.width} px</code>"
        end

        if animación.respond_to?(:height) && animación.height
            texto << "#{tab} Alto:<code> #{animación.height} px</code>"
        end

        if animación.file_name
            texto << "#{tab} Nombre:<code> "\
                     "#{html_parser(animación.file_name)}</code>"
        end
        if animación.mime_type
            texto << "#{tab} MIME:<code> "\
                     "#{animación.mime_type}</code>"
        end

        # Agrego tamaño
        tamaño = Filesize.from("#{animación.file_size} B").pretty
        texto << "#{tab} Tamaño:<code> #{tamaño}</code>" if animación.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, animación.thumb, nivel, 'Miniatura') if animación.thumb
    end

    def agregar_juego(texto, juego, nivel, pasar_entidades)
        tab = crear_tab(nivel)

        texto << "\n\n - Juego:"\
                 "#{tab} Título:<code> #{html_parser(juego.title)}</code>"\
                 "#{tab} Descripción:<code> #{html_parser(juego.description)}</code>"
        # Si hay gifs los agrego
        if juego.animation
            agregar_animación(texto, juego.animation,
                              "#{tab} Gif:", nivel + 1)
        end
        # Si hay texto lo agrego
        if juego.text
            agregar_texto(texto, "#{tab} Texto:", juego.text,
                          juego.text_entities, nivel, pasar_entidades)
        end
        # Las imágenes
        texto << "\n"
        agregar_imágenes(texto, juego.photo, "#{tab} Imagen:", nivel)
    end

    def agregar_imágenes(texto, imágenes, título, nivel)
        texto << título
        imágenes.each do |imagen|
            texto << "\n"
            agregar_imagen(texto, imagen, nivel + 1)
        end
    end

    def agregar_sticker(texto, sticker, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que siempre aparecen
        texto << "\n\n - Sticker:"\
                 "#{tab} ID:<code> #{sticker.file_id}</code>"\
                 "#{tab} Ancho:<code> #{sticker.width} px</code>"\
                 "#{tab} Alto:<code> #{sticker.height} px</code>"
        "#{tab} Animado:<code> #{sticker.is_animated ? 'Sí' : 'No'}</code>"

        texto << "#{tab} Emoji:<code> #{sticker.emoji}</code>" if sticker.emoji
        texto << "#{tab} Pack:<code> #{sticker.set_name}</code>" if sticker.set_name

        # Agrego tamaño
        tamaño = Filesize.from("#{sticker.file_size} B").pretty
        texto << "#{tab} Tamaño:<code> #{tamaño}</code>" if sticker.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, sticker.thumb, nivel, 'Miniatura') if sticker.thumb

        # Agrego posición de la máscara si tiene
        agregar_máscara(texto, sticker.mask_position, nivel) if sticker.mask_position
    end

    def agregar_video(texto, video, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Video:"\
                 "#{tab} ID:<code> #{video.file_id}</code>"\
                 "#{tab} Duración:<code> #{duracion_entera(video.duration)}</code>"\
                 "#{tab} Ancho:<code> #{video.width} px</code>"\
                 "#{tab} Alto:<code> #{video.height} px</code>"

        # Agrego datos opcionales
        texto << "#{tab} MIME:<code> #{video.mime_type}</code>" if video.mime_type

        # Agrego tamaño
        tamaño = Filesize.from("#{video.file_size} B").pretty
        texto << "#{tab} Tamaño:<code> #{tamaño}</code>" if video.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, video.thumb, nivel, 'Miniatura') if video.thumb
    end

    def agregar_msj_voz(texto, msj_voz, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Mensaje de voz:"\
                 "#{tab} ID:<code> #{msj_voz.file_id}</code>"\
                 "#{tab} Duración:<code> #{duracion_entera(msj_voz.duration)}</code>"

        # Agrego datos opcionales
        texto << "#{tab} MIME:<code> #{msj_voz.mime_type}</code>" if msj_voz.mime_type

        # Agrego tamaño
        tamaño = Filesize.from("#{msj_voz.file_size} B").pretty
        texto << "#{tab} Tamaño:<code> #{tamaño}</code>" if msj_voz.file_size
    end

    def agregar_nota_video(texto, nota_video, nivel)
        tab = crear_tab(nivel)
        duracion = duracion_entera(nota_video.duration)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Nota de video:"\
                 "#{tab} ID:<code> #{nota_video.file_id}</code>"\
                 "#{tab} Duración:<code> #{duracion}</code>"\
                 "#{tab} Ancho:<code> #{nota_video.length} px</code>"\
                 "#{tab} Alto:<code> #{nota_video.length} px</code>"

        # Agrego tamaño
        tamaño = Filesize.from("#{nota_video.file_size} B").pretty
        texto << "#{tab} Tamaño:<code> #{tamaño}</code>" if nota_video.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, nota_video.thumb, nivel, 'Miniatura') if nota_video.thumb
    end

    def agregar_contacto(texto, contacto, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Contacto:"\
                 "#{tab} Número:<code> #{contacto.phone_number}</code>"\
                 "#{tab} Nombre:<code> #{html_parser(contacto.first_name)}</code>"

        # Agrego datos opcionales
        if contacto.last_name
            texto << "#{tab} Apellido:<code> "\
                     "#{html_parser(contacto.last_name)}</code>"
        end
        if contacto.user_id
            texto << "#{tab} ID usuario:<code> "\
                     "#{contacto.user_id}</code>"
        end
        if contacto.vcard
            texto << "#{tab} vCard:<code> "\
                     "#{html_parser(contacto.vcard)}</code>"
        end
    end

    def agregar_ubicación(texto, ubicación, título, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "#{título}"\
                 "#{tab} Latitud:<code> #{ubicación.latitude}</code>"\
                 "#{tab} Longitud:<code> #{ubicación.longitude}</code>"
    end

    def agregar_venue(texto, venue, nivel)
        tab = crear_tab(nivel)

        # Título
        texto << "\n\n - Venue:"

        # Datos que seguro aparecen
        texto << "#{tab} Título:<code> #{html_parser(venue.title)}</code>"\
                 "#{tab} Dirección:<code> #{html_parser(venue.address)}</code>"

        # Datos opcionales
        if venue.foursquare_id
            texto << "#{tab} ID Foursquare:<code> "\
                     "#{venue.foursquare_id}</code>"
        end
        if venue.foursquare_type
            texto << "#{tab} Tipo Foursquare:<code> "\
                     "#{html_parser(venue.foursquare_type)}</code>"
        end

        # Ubicación
        agregar_ubicación(texto, venue.location, "#{tab} Ubicación:", nivel + 2)
    end

    def agregar_encuesta(texto, encuesta, nivel, formato = true)
        tab = crear_tab(nivel, formato)

        inic = formato ? '<code>' : ''
        fin = formato ? '</code>' : ''

        # Título
        texto << "\n\n - Encuesta:"

        # Datos que seguro aparecen
        texto << "#{tab} ID:#{inic} #{encuesta.id}#{fin}"\
                 "#{tab} Pregunta:#{inic} #{html_parser(encuesta.question)}#{fin}"\
                 "#{tab} Cerrada:#{inic} #{encuesta.is_closed ? 'Sí' : 'No'}#{fin}"

        # Agrego opciones de la encuesta
        return if encuesta.options.length.zero?

        texto << "#{tab} Opciones:"
        agregar_opciones(texto, encuesta.options, nivel + 1, formato)
    end

    # TODO
    def agregar_pago(texto, pago_exitoso, nivel); end

    def agregar_pasaporte(texto, data_pasaporte, nivel); end

    def agregar_botones(texto, tablero, nivel); end

    def agregar_eventos_chat(texto, msj, nivel); end

    def agregar_imagen(texto, imagen, nivel, título = nil)
        # Creo tabs
        tab1 = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)

        tab = título ? tab2 : tab1

        # Agrego imagen
        texto << "#{tab1} #{título}:" if título

        # Agrego datos imagen
        texto << "#{tab} ID:<code> #{imagen.file_id}</code>"\
                 "#{tab} Ancho:<code> #{imagen.width} px</code>"\
                 "#{tab} Alto:<code> #{imagen.height} px</code>"

        # Dato opcional
        if imagen.file_size
            tamaño = Filesize.from("#{imagen.file_size} B").pretty
            texto << "#{tab} Tamaño:<code> #{tamaño}</code>"
        end
    end

    def agregar_máscara(texto, máscara, nivel)
        tab1 = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)

        texto << "#{tab1} Máscara:"\
                 "#{tab2} Punto:<code> #{máscara.point}</code>"\
                 "#{tab2} x_shift:<code> #{máscara.x_shift}</code>"\
                 "#{tab2} y_shift:<code> #{máscara.y_shift}</code>"\
                 "#{tab2} Escala:<code> #{máscara.scale}</code>"
    end

    def duracion_entera(seg_totales)
        # 3600 = 60*60
        horas = seg_totales / 3600
        minutos = (seg_totales / 60) % 60
        segundos = seg_totales % 60

        # Agrego ceros si es un solo dígito y devuelvo
        [horas, minutos, segundos].map do |t|
            t.round.to_s.rjust(2, '0')
        end.join(':')
    end

    def agregar_opciones(texto, opciones, nivel, formato = true)
        tab = crear_tab(nivel, formato)
        tab2 = crear_tab(nivel + 1, formato)

        inic = formato ? '<code>' : ''
        fin = formato ? '</code>' : ''
        inic_opción = formato ? '<b>' : ''
        fin_opción = formato ? '</b>' : ''

        # Pongo las opciones
        opciones.each_with_index do |opción, índice|
            texto << "#{tab} Opción #{inic_opción}#{índice + 1}#{fin_opción}:"\
                     "#{tab2} Texto:#{inic} #{html_parser(opción.text)}#{fin}"\
                     "#{tab2} Votos:#{inic} #{opción.voter_count}#{fin}"
        end
    end

    def crear_tab(profundidad, formato = true)
        tab = "\n"
        tab << '<code>' if formato

        profundidad.times do
            tab << "\t\t"
        end

        tab << '</code>' if formato
        tab << ' -'
    end
end
