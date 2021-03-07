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
            if pasar_entidades && !DEVS.include?(msj.from.id)
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
        texto << "\n - ID del mensaje: <code>#{msj.message_id}</code>"
        # Fecha del mensaje
        fecha = Time.at(msj.date, in: @tz.utc_offset).to_datetime
        texto << "\n - Fecha envío: <code>#{fecha.strftime('%d/%m/%Y %T %Z')}</code>"

        agregar_datos_opcionales_msj(texto, msj, nivel)

        # Agrego chat
        agregar_chat(texto, msj.chat, "\n\n -Chat:", nivel + 1)
        # Agregar info reenvío
        agregar_info_reenvío(texto, msj, nivel + 1) if msj.forward_date
    end

    def agregar_datos_opcionales_msj(texto, msj, nivel)
        # Fecha de última edición del mensaje
        if msj.edit_date
            fecha_edición = Time.at(msj.edit_date, in: @tz.utc_offset).to_datetime
            fecha_edición = fecha_edición.strftime('%d/%m/%Y %T %Z')
            texto << "\n- Última edición: <code>#{fecha_edición}</code>"
        end

        # Si hay multimedia, mando el id de mensaje multimedia
        if msj.media_group_id
            texto << "\n - ID del mensaje multimedia:"\
                     " <code>#{msj.media_group_id}</code>"
        end

        # Si se conectó a un sitio
        if msj.connected_website
            texto << "\n - Sitio web conectado:"\
                     " <code>#{msj.connected_website}</code>"
        end

        # Si hay autor, lo agrego
        if msj.author_signature
            texto << "\n - Autor: "\
                     "#{html_parser(msj.author_signature)}"
        end

        if msj.respond_to?(:via_bot) && msj.via_bot
            agregar_datos_opc_usuario(msj, texto, nivel, '- Vía bot:', msj.via_bot)
        end

        # Agrego usuario
        return unless msj.from

        agregar_datos_opc_usuario(msj, texto, nivel, '- Enviado por:', msj.from)
    end

    def agregar_datos_opc_usuario(msj, texto, nivel, título_msj, miembro)
        cuenta_eliminada = '<code>cuenta eliminada</code>'
        usuario = obtener_enlace_usuario(miembro, msj.chat.id) || cuenta_eliminada
        título = "\n\n #{título_msj} #{usuario}"
        agregar_usuario(texto, miembro, título, nivel + 1)
    end

    def agregar_usuario(texto, usuario, título, nivel)
        tab = crear_tab(nivel)

        # Agrego título, id y si es bot
        texto << "#{título}"\
                 "#{tab} ID: <code>#{usuario.id}</code>"\
                 "#{tab} Bot: <code>#{usuario.is_bot ? 'Sí' : 'No'}</code>"\

        # Me fijo si es cuenta eliminada, y si no, pongo 1er y 2do nombre, y alias
        texto << "#{tab} Cuenta Eliminada:"
        if usuario.first_name.empty?
            texto << ' <code>Sí</code>'
        else
            texto << ' <code>No</code>'
            agregar_nombres(texto, usuario, nivel)

            # Código de lenguaje si tiene
            if usuario.language_code
                texto << "#{tab} Código de lenguaje:"\
                         " <code>#{usuario.language_code}</code>"
            end
        end
    end

    def agregar_chat(texto, chat, título, nivel)
        tab = crear_tab(nivel)

        # Agrego id y tipo
        texto << "#{título}"\
                 "#{tab} ID: <code>#{chat.id}</code>"\
                 "#{tab} Tipo: <code>#{chat.type}</code>"

        # Agrego título si tiene, si no info del chat privado
        texto << "#{tab} Título: <code>#{html_parser(chat.title)}</code>" if chat.title
        # Agrego nombre, apellido y alias si hay
        agregar_nombres(texto, chat, nivel)
    end

    def agregar_nombres(texto, elemento, nivel)
        tab = crear_tab(nivel)

        # Pongo primer nombre
        if elemento.first_name
            texto << "#{tab} Nombre: <code>"\
                     "#{html_parser(elemento.first_name)}</code>"
        end

        # Segundo nombre si tiene
        if elemento.last_name
            texto << "#{tab} Apellido: <code>"\
                     "#{html_parser(elemento.last_name)}</code>"
        end

        # Alias si tiene
        alias_usuario = if elemento.username
                            " <code>#{elemento.username}</code>"
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
                 "#{tab} Fecha envío original: <code>#{fecha_reenvío}</code>"

        # Info del usuario original
        if msj.forward_from
            texto << "#{tab} Cuenta oculta: <code>No</code>"
            usuario = obtener_enlace_usuario(msj.forward_from,
                                             msj.chat.id) || '<i>Cuenta eliminada</i>'
            título = "#{tab} Reenviado de: #{usuario}"
            agregar_usuario(texto, msj.forward_from, título, nivel + 1)
        elsif msj.forward_sender_name
            # Si es una cuenta oculta
            texto << "#{tab} Cuenta oculta: <code>Sí</code>"
            nombre = html_parser(msj.forward_sender_name)
            texto << "#{tab} Nombre: <code>#{nombre}</code>"
        elsif msj.forward_from_chat
            agregar_reenvío_canal(texto, tab, msj, nivel)
        end
    end

    def agregar_reenvío_canal(texto, tab, msj, nivel)
        # Si es reenviado de un canal
        texto << "#{tab} Reenviado de un canal: <code>Sí</code>"\

        # Si tengo el id original del mensaje
        if msj.forward_from_message_id
            texto << "#{tab} ID mensaje original: <code>"\
                        "#{msj.forward_from_message_id}</code>"
        end

        # Si tengo la firma del mensaje
        if msj.forward_signature
            texto << "#{tab} Firma: <code>"\
                        "#{html_parser(msj.forward_signature)}</code>"
        end

        # Agrego información del Canal original
        título = "#{tab} Canal original del mensaje:"
        agregar_chat(texto, msj.forward_from_chat, título, nivel + 1)
    end

    def agregar_contenido(respuesta, msj, nivel, pasar_entidades)
        agregar_dado(msj.dice, respuesta, nivel) if msj.dice

        # Agrego texto si hay
        agregar_texto(
            respuesta: respuesta,
            título: 'Texto:',
            texto_msj: msj.text,
            entidades: msj.entities,
            nivel: nivel,
            pasar_entidades: pasar_entidades
        )

        agregar_multimedia(respuesta, msj, nivel)

        agregar_encuesta(respuesta, msj.poll, nivel, pasar_entidades) if msj.poll

        if msj.location
            agregar_ubicación(respuesta, msj.location, "\n\n - Ubicación:", nivel)
        end

        agregar_contacto(respuesta, msj.contact, nivel) if msj.contact
        agregar_juego(respuesta, msj.game, nivel, pasar_entidades) if msj.game
        agregar_botones(respuesta, msj.reply_markup, nivel) if msj.reply_markup

        agregar_eventos_chat(respuesta, msj, nivel, pasar_entidades)

        # Agrego caption si hay
        agregar_texto(
            respuesta: respuesta,
            título: 'Epígrafe:',
            texto_msj: msj.caption,
            entidades: msj.caption_entities,
            nivel: nivel,
            pasar_entidades: pasar_entidades
        )
    end

    def agregar_dado(dado, texto, nivel)
        tab = crear_tab(nivel)

        texto << "\n\n - Dado:"
        texto << "#{tab} Emoji: #{dado.emoji}"
        texto << "#{tab} Valor: <code>#{dado.value}</code>"
    end

    def agregar_multimedia(respuesta, msj, nivel)
        unless msj.photo.empty?
            agregar_imágenes(respuesta, msj.photo, "\n\n - Imagen:", nivel)
        end
        if msj.animation
            agregar_animación(respuesta, msj.animation, "\n\n - Gif:", nivel)
        end

        agregar_sticker(respuesta, msj.sticker, nivel) if msj.sticker
        agregar_audio(respuesta, msj.audio, nivel) if msj.audio
        agregar_msj_voz(respuesta, msj.voice, nivel) if msj.voice
        agregar_video(respuesta, msj.video, nivel) if msj.video
        agregar_nota_video(respuesta, msj.video_note, nivel) if msj.video_note

        agregar_extras(respuesta, msj, nivel)

        return unless msj.document && msj.animation.nil?

        agregar_documento(respuesta, msj.document, nivel)
    end

    def agregar_extras(respuesta, msj, nivel)
        agregar_venue(respuesta, msj.venue, nivel) if msj.venue
        agregar_pasaporte(respuesta, msj.passport_data, nivel) if msj.passport_data
        agregar_factura(respuesta, msj.invoice, nivel) if msj.invoice
        agregar_pago(respuesta, msj.successful_payment, nivel) if msj.successful_payment
    end

    def agregar_texto(params)
        texto_msj = params[:texto_msj]
        respuesta = params[:respuesta]
        entidades = params[:entidades]
        título = params[:título]

        return unless texto_msj

        long = texto_msj.length

        # Agrego el texto
        texto_msj = "#{texto_msj[0..200]}..." if long > 200
        respuesta << "\n\n - #{título} <code>#{html_parser(texto_msj)}</code>"
        respuesta << "\n - Longitud: <code>#{long}</code>"

        # Agrego las entidades
        respuesta << "\n - Entidades del #{título.downcase}"\
                     " <code>#{entidades.length}</code>"

        return if entidades.empty? || !params[:pasar_entidades]

        agregar_entidades(params[:nivel], entidades, respuesta)
    end

    def agregar_entidades(nivel, entidades, respuesta)
        # Creo tabs
        tab1 = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)

        entidades.each_with_index do |entidad, índice|
            # Nro entidad
            respuesta << "#{tab1} Entidad <b>#{índice + 1}</b>:"\
                         "#{tab2} Tipo: <code>#{entidad.type}</code>"\
                         "#{tab2} Desfasaje: <code>#{entidad.offset}</code>"\
                         "#{tab2} Longitud: <code>#{entidad.length}</code>"

            if entidad.url
                respuesta << "#{tab2} Enlace: "\
                             "<code>#{html_parser(entidad.url)}</code>"
            end

            if entidad.language
                respuesta << "#{tab2} Lenguaje de programación: "\
                             "<code>#{entidad.language}</code>"
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
                 "#{tab} ID: <code>#{audio.file_id}</code>"\
                 "#{tab} Id único: <code>#{audio.file_unique_id}</code>"\
                 "#{tab} Duración: <code>#{duración_entera(audio.duration)}</code>"

        # Agrego datos opcionales
        if audio.performer
            texto << "#{tab} Artista: <code>"\
                     "#{html_parser(audio.performer)}</code>"
        end
        if audio.title
            texto << "#{tab} Título: <code>"\
                     "#{html_parser(audio.title)}</code>"
        end
        texto << "#{tab} MIME: <code>#{audio.mime_type}</code>" if audio.mime_type

        # Agrego tamaño
        tamaño = Filesize.from("#{audio.file_size} B").pretty
        texto << "#{tab} Tamaño: <code>#{tamaño}</code>" if audio.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, audio.thumb, nivel, 'Miniatura') if audio.thumb
    end

    def agregar_documento(texto, doc, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Documento:"\
                 "#{tab} ID: <code>#{doc.file_id}</code>"\
                 "#{tab} Id único: <code>#{doc.file_unique_id}</code>"

        # Agrego datos opcionales
        if doc.file_name
            texto << "#{tab} Nombre: <code>"\
                     "#{html_parser(doc.file_name)}</code>"
        end
        texto << "#{tab} MIME: <code>#{doc.mime_type}</code>" if doc.mime_type

        # Agrego tamaño
        tamaño = Filesize.from("#{doc.file_size} B").pretty
        texto << "#{tab} Tamaño: <code>#{tamaño}</code>" if doc.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, doc.thumb, nivel, 'Miniatura') if doc.thumb
    end

    def agregar_animación(texto, animación, título, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "#{título}"\
                 "#{tab} ID: <code>#{animación.file_id}</code>"\
                 "#{tab} Id único: <code>#{animación.file_unique_id}</code>"

        agregar_datos_animación(animación, tab, texto)

        # Agrego tamaño
        tamaño = Filesize.from("#{animación.file_size} B").pretty
        texto << "#{tab} Tamaño: <code>#{tamaño}</code>" if animación.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, animación.thumb, nivel, 'Miniatura') if animación.thumb
    end

    def agregar_datos_animación(animación, tab, texto)
        # Agrego datos opcionales
        if animación.respond_to?(:duration) && animación.duration
            duración = duración_entera(animación.duration)
            texto << "#{tab} Duración: <code>#{duración}</code>"
        end

        if animación.respond_to?(:width) && animación.width
            texto << "#{tab} Ancho: <code>#{animación.width} px</code>"
        end

        if animación.respond_to?(:height) && animación.height
            texto << "#{tab} Alto: <code>#{animación.height} px</code>"
        end

        if animación.file_name
            texto << "#{tab} Nombre: <code>"\
                     "#{html_parser(animación.file_name)}</code>"
        end

        return unless animación.mime_type

        texto << "#{tab} MIME: <code>#{animación.mime_type}</code>"
    end

    def agregar_juego(texto, juego, nivel, pasar_entidades)
        tab = crear_tab(nivel)

        texto << "\n\n - Juego:"\
                 "#{tab} Título: <code>#{html_parser(juego.title)}</code>"\
                 "#{tab} Descripción: <code>#{html_parser(juego.description)}</code>"
        # Si hay gifs los agrego
        if juego.animation
            agregar_animación(texto, juego.animation,
                              "#{tab} Gif:", nivel + 1)
        end
        # Si hay texto lo agrego
        if juego.text
            agregar_texto(
                respuesta: texto,
                título: "#{tab} Texto:",
                texto_msj: juego.text,
                entidades: juego.text_entities,
                nivel: nivel,
                pasar_entidades: pasar_entidades
            )
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
        texto << "\n\n - Sticker:"
        texto << "#{tab} ID: <code>#{sticker.file_id}</code>"
        texto << "#{tab} Id único: <code>#{sticker.file_unique_id}</code>"
        texto << "#{tab} Ancho: <code>#{sticker.width} px</code>"
        texto << "#{tab} Alto: <code>#{sticker.height} px</code>"
        texto << "#{tab} Animado: <code>#{sticker.is_animated ? 'Sí' : 'No'}</code>"

        texto << "#{tab} Emoji: <code>#{sticker.emoji}</code>" if sticker.emoji
        texto << "#{tab} Pack: <code>#{sticker.set_name}</code>" if sticker.set_name

        # Agrego tamaño
        tamaño = Filesize.from("#{sticker.file_size} B").pretty
        texto << "#{tab} Tamaño: <code>#{tamaño}</code>" if sticker.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, sticker.thumb, nivel, 'Miniatura') if sticker.thumb

        # Agrego posición de la máscara si tiene
        agregar_máscara(texto, sticker.mask_position, nivel) if sticker.mask_position
    end

    def agregar_video(texto, video, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Video:"
        texto << "#{tab} ID: <code>#{video.file_id}</code>"
        texto << "#{tab} Id único: <code>#{video.file_unique_id}</code>"
        texto << "#{tab} Duración: <code>#{duración_entera(video.duration)}</code>"
        texto << "#{tab} Ancho: <code>#{video.width} px</code>"
        texto << "#{tab} Alto: <code>#{video.height} px</code>"

        # Agrego datos opcionales
        texto << "#{tab} MIME: <code>#{video.mime_type}</code>" if video.mime_type

        # Agrego tamaño
        tamaño = Filesize.from("#{video.file_size} B").pretty
        texto << "#{tab} Tamaño: <code>#{tamaño}</code>" if video.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, video.thumb, nivel, 'Miniatura') if video.thumb
    end

    def agregar_msj_voz(texto, msj_voz, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Mensaje de voz:"\
                 "#{tab} ID: <code>#{msj_voz.file_id}</code>"\
                 "#{tab} Id único: <code>#{msj_voz.file_unique_id}</code>"\
                 "#{tab} Duración: <code>#{duración_entera(msj_voz.duration)}</code>"

        # Agrego datos opcionales
        texto << "#{tab} MIME: <code>#{msj_voz.mime_type}</code>" if msj_voz.mime_type

        # Agrego tamaño
        tamaño = Filesize.from("#{msj_voz.file_size} B").pretty
        texto << "#{tab} Tamaño: <code>#{tamaño}</code>" if msj_voz.file_size
    end

    def agregar_nota_video(texto, nota_video, nivel)
        tab = crear_tab(nivel)
        duración = duración_entera(nota_video.duration)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Nota de video:"\
                 "#{tab} ID: <code>#{nota_video.file_id}</code>"\
                 "#{tab} Id único: <code>#{nota_video.file_unique_id}</code>"\
                 "#{tab} Duración: <code>#{duración}</code>"\
                 "#{tab} Ancho: <code>#{nota_video.length} px</code>"\
                 "#{tab} Alto: <code>#{nota_video.length} px</code>"

        # Agrego tamaño
        tamaño = Filesize.from("#{nota_video.file_size} B").pretty
        texto << "#{tab} Tamaño: <code>#{tamaño}</code>" if nota_video.file_size

        # Agrego imagen si tiene
        agregar_imagen(texto, nota_video.thumb, nivel, 'Miniatura') if nota_video.thumb
    end

    def agregar_contacto(texto, contacto, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Contacto:"\
                 "#{tab} Número: <code>#{contacto.phone_number}</code>"\
                 "#{tab} Nombre: <code>#{html_parser(contacto.first_name)}</code>"

        # Agrego datos opcionales
        if contacto.last_name
            texto << "#{tab} Apellido: <code>"\
                     "#{html_parser(contacto.last_name)}</code>"
        end
        if contacto.user_id
            texto << "#{tab} ID usuario: <code>"\
                     "#{contacto.user_id}</code>"
        end

        return unless contacto.vcard

        texto << "#{tab} vCard: <code>#{html_parser(contacto.vcard)}</code>"
    end

    def agregar_ubicación(texto, ubicación, título, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "#{título}"\
                 "#{tab} Latitud: <code>#{ubicación.latitude}</code>"\
                 "#{tab} Longitud: <code>#{ubicación.longitude}</code>"
    end

    def agregar_venue(texto, venue, nivel)
        tab = crear_tab(nivel)

        # Título
        texto << "\n\n - Venue:"

        # Datos que seguro aparecen
        texto << "#{tab} Título: <code>#{html_parser(venue.title)}</code>"\
                 "#{tab} Dirección: <code>#{html_parser(venue.address)}</code>"

        # Datos opcionales
        if venue.foursquare_id
            texto << "#{tab} ID Foursquare: <code>"\
                     "#{venue.foursquare_id}</code>"
        end
        if venue.foursquare_type
            texto << "#{tab} Tipo Foursquare: <code>"\
                     "#{html_parser(venue.foursquare_type)}</code>"
        end

        # Ubicación
        agregar_ubicación(texto, venue.location, "#{tab} Ubicación:", nivel + 2)
    end

    def agregar_encuesta(texto, encuesta, nivel, pasar_entidades, formato: true)
        tab = crear_tab(nivel, formato: formato)

        inic = formato ? '<code>' : ''
        fin = formato ? '</code>' : ''

        # Título
        texto << "\n\n - Encuesta:"

        # Datos que seguro aparecen
        texto << "#{tab} ID:#{inic} #{encuesta.id}#{fin}"\
                 "#{tab} Pregunta:#{inic}#{html_parser(encuesta.question)}#{fin}"\
                 "#{tab} Cerrada:#{inic}#{encuesta.is_closed ? 'Sí' : 'No'}#{fin}"\
                 "#{tab} Cantidad de votos: #{inic}#{encuesta.total_voter_count}#{fin}"\
                 "#{tab} Anónima:#{inic}#{encuesta.is_anonymous ? 'Sí' : 'No'}#{fin}"\
                 "#{tab} Tipo: #{inic}#{encuesta.type}#{fin}"\
                 "#{tab} Acepta respuesta múltiple: #{inic}"\
                 "#{encuesta.allows_multiple_answers ? 'Sí' : 'No'}#{fin}"

        if encuesta.correct_option_id
            nro = encuesta.correct_option_id + 1
            texto << "#{tab} Opción correcta: #{inic}#{nro}#{fin}"
        end

        if encuesta.respond_to? :explanation
            agregar_texto(
                respuesta: texto,
                título: 'Explicación:',
                texto_msj: encuesta.explanation,
                entidades: encuesta.explanation_entities,
                nivel: nivel,
                pasar_entidades: pasar_entidades
            )
        end

        agregar_extras_encuesta(
            encuesta: encuesta,
            tab: tab,
            inic: inic,
            fin: fin,
            texto: texto,
            nivel: nivel,
            pasar_entidades: pasar_entidades,
            formato: formato
        )
    end

    def agregar_extras_encuesta(params)
        agregar_valores_extras_encuesta(params)
        encuesta = params[:encuesta]
        texto = params[:texto]
        nivel = params[:nivel]

        if encuesta.respond_to?(:explanation_entities) && params[:pasar_entidades] &&
           encuesta.explanation_entities.positive?

            agregar_entidades(nivel, encuesta.explanation_entities, texto)
        end

        # Agrego opciones de la encuesta
        return if encuesta.options.length.zero?

        texto << "#{params[:tab]} Opciones:"
        agregar_opciones(
            texto,
            encuesta.options,
            nivel + 1,
            encuesta.is_closed,
            formato: params[:formato]
        )
    end

    def agregar_valores_extras_encuesta(params)
        encuesta = params[:encuesta]
        tab = params[:tab]
        inic = params[:inic]
        fin = params[:fin]
        texto = params[:texto]

        if encuesta.respond_to?(:explanation) && encuesta.explanation
            exp = html_parser encuesta.explanation
            texto << "#{tab} Explicación: #{inic}#{exp}#{fin}"
        end

        if encuesta.respond_to?(:open_period) && encuesta.open_period
            texto << "#{tab} Tiempo activo desde la creación: #{inic}"\
                     "#{duración_entera(encuesta.open_period)}#{fin}"
        end

        return unless encuesta.respond_to?(:close_date) && encuesta.close_date

        fecha = Time.at(encuesta.close_date, in: @tz.utc_offset).to_datetime
        fecha = fecha.strftime('%d/%m/%Y %T %Z')
        texto << "#{tab} Fin de encuesta: #{inic}#{fecha}#{fin}"
    end

    def agregar_factura(texto, factura, nivel)
        tab = crear_tab(nivel)

        # Título
        texto << "\n\n - Factura:"

        # Datos
        texto << "#{tab} Título: <code>#{html_parser(factura.title)}</code>"\
                 "#{tab} Descripción: <code>#{html_parser(factura.description)}</code>"\
                 "#{tab} Parámetro de Inicio: "\
                        "<code>#{html_parser(factura.start_parameter)}</code>"\
                 "#{tab} Código de Divisa: <code>#{factura.currency}</code>"

        total = factura.currency.to_s
        total = "#{total[0..-3]},#{total[-2..]}"

        texto << "#{tab} Total facturado: <code>#{total}</code>"
    end

    def agregar_pago(texto, pago_exitoso, nivel)
        tab = crear_tab(nivel)

        # Título
        texto << "\n\n - Pago exitoso:"

        # Datos
        texto << "#{tab} Código de divisa: <code>#{pago_exitoso.currency}</code>"

        total = pago_exitoso.currency.to_s
        total = "#{total[0..-3]},#{total[-2..]}"
        texto << "#{tab} Total facturado: <code>#{total}</code>"

        factura = html_parser(pago_exitoso.invoice_payload)
        texto << "#{tab} Factura del pago: <code>#{factura}</code>"

        if pago_exitoso.invoice_payload
            id_opción_envío = html_parser(pago_exitoso.invoice_payload)
            texto << "#{tab} ID opción de envío: <code>#{id_opción_envío}</code>"
        end

        id_pago_telegram = html_parser(pago_exitoso.telegram_payment_charge_id)
        texto << "#{tab} ID pago telegram: <code>#{id_pago_telegram}</code>"

        id_pago_proveedor = html_parser(pago_exitoso.provider_payment_charge_id)
        texto << "#{tab} ID pago proveedor: <code>#{id_pago_proveedor}</code>"

        return unless pago_exitoso.order_info

        agregar_info_orden(texto, tab, pago_exitoso)

        return unless info_orden.shipping_address

        agregar_shipping_address(texto, tab2, nivel, info_orden)
    end

    def agregar_info_orden(texto, tab, pago_exitoso)
        texto << "#{tab} Información de la orden:"

        tab2 = crear_tab(nivel + 1)
        info_orden = pago_exitoso.order_info

        if info_orden.name
            texto << "#{tab2} Nombre: <code>#{html_parser(info_orden.name)}</code>"
        end

        if info_orden.phone_number
            texto << "#{tab2} Número de teléfono: "\
                     "<code>#{info_orden.phone_number}</code>"
        end

        return unless info_orden.email

        texto << "#{tab2} Email: <code>#{html_parser(info_orden.email)}</code>"
    end

    def agregar_shipping_address(texto, tab2, nivel, info_orden)
        texto << "#{tab2} Información del envío:"

        tab3 = crear_tab(nivel + 2)
        dir_envío = info_orden.shipping_address

        texto << "#{tab3} Código de país: <code>#{dir_envío.country_code}</code>"\
                 "#{tab3} Estado: <code>#{html_parser(dir_envío.state)}</code>"\
                 "#{tab3} Ciudad: <code>#{html_parser(dir_envío.city)}</code>"\
                 "#{tab3} Parte 1 dirección: "\
                         "<code>#{html_parser(dir_envío.street_line1)}</code>"\
                 "#{tab3} Parte 2 dirección: "\
                         "<code>#{html_parser(dir_envío.street_line2)}</code>"\
                 "#{tab3} Código Postal: <code>#{dir_envío.post_code}</code>"
    end

    def agregar_pasaporte(texto, data_pasaporte, nivel)
        tab = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)

        # Título
        texto << "\n\n - Pasaporte:"

        # Datos
        unless data_pasaporte.data.empty?
            texto << "#{tab} Data:"
            data_pasaporte.data.each_with_index do |elem, índice|
                texto << "#{tab2} Elemento #{índice + 1}:"
                agregar_elemento_pasaporte(texto, elem, nivel + 2)
            end
            texto << "\n"
        end

        # Credenciales
        credenciales = data_pasaporte.credentials

        texto << "#{tab} Credenciales:"\
                 "#{tab2} Data: <code>#{credenciales.data}</code>"\
                 "#{tab2} Hash: <code>#{credenciales.hash}</code>"\
                 "#{tab2} Secreto: <code>#{credenciales.secret}</code>"
    end

    def agregar_botones(texto, tablero, nivel)
        tab = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)
        tab3 = crear_tab(nivel + 2)

        # Título
        texto << "\n\n - Botonera:"

        botonera = tablero.inline_keyboard
        if botonera.empty?
            texto << ' <b>LA BOTONERA ESTÁ VACÍA</b>'
            return
        end

        texto << "\n#{tab} Botones:\n"

        # Matriz de botonazos
        botonera.each_with_index do |fila, índice|
            texto << "#{tab2} Fila #{índice + 1}:"

            if fila.empty?
                texto << ' <b>FILA VACÍA</b>'
            else
                fila.each_with_index do |botón, índice2|
                    texto << "#{tab3} Botón #{índice2 + 1}:"
                    agregar_botón(texto, botón, nivel + 3)
                end
            end

            texto << "\n"
        end
    end

    def agregar_eventos_chat(texto, msj, nivel, pasar_entidades)
        tab = crear_tab(nivel)

        agregar_eventos_usuario(msj, texto, tab, nivel)
        agregar_eventos_foto_chat(msj, texto, nivel)

        if msj.new_chat_title
            texto << "\n\n - Nuevo título: #{html_parser(msj.new_chat_title)}"
        end

        texto << "\n\n - ¿Grupo creado?: <code>Sí</code>" if msj.group_chat_created

        if msj.supergroup_chat_created
            texto << "\n\n - ¿Supergrupo creado?: <code>Sí</code>"
        end

        texto << "\n\n - ¿Canal creado?: <code>Sí</code>" if msj.channel_chat_created

        if msj.migrate_to_chat_id
            texto << "\n\n - ID del supergrupo al que se migró: "\
                     "<code>#{msj.migrate_to_chat_id}</code>"
        end

        if msj.migrate_from_chat_id
            texto << "\n\n - ID del grupo desde el que se migró: "\
                     "<code>#{msj.migrate_from_chat_id}</code>"
        end

        return unless msj.pinned_message

        texto << "\n\n\n - Mensaje anclado:\n\n<code>------------</code>\n"
        agregar_datos_mensaje(msj.pinned_message, texto, pasar_entidades, nivel + 2)
    end

    def agregar_eventos_usuario(msj, texto, tab, nivel)
        unless msj.new_chat_members.empty?
            texto << "\n\n - Nuevos miembros:"

            msj.new_chat_members.each_with_index do |miembro, índice|
                título = "\n#{tab} Nuevo miembro #{índice + 1}:"
                agregar_usuario(texto, miembro, título, nivel + 1)
            end
        end

        return unless msj.left_chat_member

        título = "\n\n - Miembro eliminado:"
        agregar_usuario(texto, msj.left_chat_member, título, nivel)
    end

    def agregar_eventos_foto_chat(msj, texto, nivel)
        unless msj.new_chat_photo.empty?
            agregar_imágenes(
                texto,
                msj.new_chat_photo,
                "\n\n - Nueva imagen del chat:",
                nivel
            )
        end

        return unless msj.delete_chat_photo

        texto << "\n\n - ¿Imagen del chat borrada?: <code>Sí</code>"
    end

    def agregar_imagen(texto, imagen, nivel, título = nil)
        # Creo tabs
        tab1 = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)

        tab = título ? tab2 : tab1

        # Agrego imagen
        texto << "#{tab1} #{título}:" if título

        # Agrego datos imagen
        texto << "#{tab} ID: <code>#{imagen.file_id}</code>"\
                 "#{tab} Id único: <code>#{imagen.file_unique_id}</code>"\
                 "#{tab} Ancho: <code>#{imagen.width} px</code>"\
                 "#{tab} Alto: <code>#{imagen.height} px</code>"

        # Dato opcional
        return unless imagen.file_size

        tamaño = Filesize.from("#{imagen.file_size} B").pretty
        texto << "#{tab} Tamaño: <code>#{tamaño}</code>"
    end

    def agregar_máscara(texto, máscara, nivel)
        tab1 = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)

        texto << "#{tab1} Máscara:"\
                 "#{tab2} Punto: <code>#{máscara.point}</code>"\
                 "#{tab2} x_shift: <code>#{máscara.x_shift}</code>"\
                 "#{tab2} y_shift: <code>#{máscara.y_shift}</code>"\
                 "#{tab2} Escala: <code>#{máscara.scale}</code>"
    end

    def duración_entera(seg_totales)
        # 3600 = 60*60
        horas = seg_totales / 3600
        minutos = (seg_totales / 60) % 60
        segundos = seg_totales % 60

        # Agrego ceros si es un solo dígito y devuelvo
        [horas, minutos, segundos].map do |t|
            t.round.to_s.rjust(2, '0')
        end.join(':')
    end

    def agregar_opciones(texto, opciones, nivel, terminada, formato: true)
        tab = crear_tab(nivel, formato: formato)
        tab2 = crear_tab(nivel + 1, formato: formato)

        inic = formato ? '<code>' : ''
        fin = formato ? '</code>' : ''
        inic_opción = formato ? '<b>' : ''
        fin_opción = formato ? '</b>' : ''

        # Pongo las opciones
        opciones.each_with_index do |opción, índice|
            texto << "#{tab} Opción #{inic_opción}#{índice + 1}#{fin_opción}:"\
                     "#{tab2} Texto:#{inic} #{html_parser(opción.text)}#{fin}"
            texto << "#{tab2} Votos:#{inic} #{opción.voter_count}#{fin}" if terminada
        end
    end

    def agregar_elemento_pasaporte(texto, elem, nivel)
        tab = crear_tab(nivel)
        tab2 = crear_tab(nivel + 1)

        texto << "#{tab} Tipo: <code>#{elem.type}</code>"
        texto << "#{tab} Data: <code>#{elem.data}</code>" if elem.data

        if elem.phone_number
            texto << "#{tab} Teléfono: <code>#{elem.phone_number}</code>"
        end

        texto << "#{tab} Email: <code>#{html_parser(elem.email)}</code>" if elem.email
        texto << "#{tab} Hash: <code>#{elem.hash}</code>"

        agregar_partes_elemento

        return if elem.translation.empty?

        texto << "#{tab} Traducciones:"
        elem.translation.each_with_index do |archivo, índice|
            texto << "#{tab2} Traducción #{índice + 1}:"
            agregar_archivo_pasaporte(texto, archivo, nivel + 2)
        end
        texto << "\n"
    end

    def agregar_partes_elemento(elem, texto, tab, tab2, nivel)
        unless elem.files.empty?
            texto << "#{tab} Archivos:"
            elem.files.each_with_index do |archivo, índice|
                texto << "#{tab2} Archivo #{índice + 1}:"
                agregar_archivo_pasaporte(texto, archivo, nivel + 2)
            end
            texto << "\n"
        end

        if elem.front_side
            texto << "#{tab} Frente documento:"
            agregar_archivo_pasaporte(texto, elem.front_side, nivel + 1)
            texto << "\n"
        end

        if elem.reverse_side
            texto << "#{tab} Reverso documento:"
            agregar_archivo_pasaporte(texto, elem.reverse_side, nivel + 1)
            texto << "\n"
        end

        return unless elem.selfie

        texto << "#{tab} Selfie:"
        agregar_archivo_pasaporte(texto, elem.selfie, nivel + 1)
        texto << "\n"
    end

    def agregar_archivo_pasaporte(texto, archivo, nivel)
        tab = crear_tab(nivel)

        tamaño = Filesize.from("#{archivo.file_size} B").pretty
        fecha = Time.at(archivo.file_date, in: @tz.utc_offset).to_datetime

        texto << "#{tab} ID archivo: <code>#{archivo.file_id}</code>"\
                 "#{tab} Id único: <code>#{archivo.file_unique_id}</code>"
        "#{tab} Tamaño: <code>#{tamaño}</code>"\
        "#{tab} Fecha subida: <code>#{fecha.strftime('%d/%m/%Y %T %Z')}</code>"
    end

    def agregar_botón(texto, botón, nivel)
        tab = crear_tab(nivel)
        texto << "#{tab} Texto: <code>#{html_parser(botón['text'])}</code>"

        if botón.key?('url') && botón['url']
            texto << "#{tab} URL: <code>#{html_parser(botón['url'])}</code>"
        end

        if botón.key?('callback_data') && botón['callback_data']
            texto << "#{tab} Data: <code>#{html_parser(botón['callback_data'])}</code>"
        end

        if botón.key?('pay') && botón['pay']
            texto << "#{tab} Pago: <code>#{botón['pay'] ? 'Sí' : 'No'}</code>"
        end

        if botón.key?('callback_game') && botón['callback_game']
            texto << "#{tab} Juego: <code>#{html_parser(botón['callback_game'])}</code>"
        end

        agregar_switch_inline_botón(botón, tab, texto)
        agregar_url_botón(botón, nivel, tab, texto)
    end

    def agregar_switch_inline_botón(botón, tab, texto)
        if botón.key?('switch_inline_query') && botón['switch_inline_query']
            string = if botón['switch_inline_query'].empty?
                         '<b>STRING VACÍO</b>'
                     else
                         "<code>#{html_parser(botón['switch_inline_query'])}</code>"
                     end

            texto << "#{tab} Cambio a query inline: #{string}"
        end

        return unless botón.key?('switch_inline_query_current_chat') &&
                      botón['switch_inline_query_current_chat']

        string = botón['switch_inline_query_current_chat']
        string = if string.empty?
                     '<b>STRING VACÍO</b>'
                 else
                     "<code>#{html_parser(string)}</code>"
                 end

        texto << "#{tab} Cambio a query inline en el chat actual: #{string}"
    end

    def agregar_url_botón(botón, nivel, tab, texto)
        return unless botón.key?('login_url') && botón['login_url']

        tab2 = crear_tab(nivel + 1)
        login = botón['login_url']

        texto << "#{tab} URL login:"

        texto << "#{tab2} URL: <code>#{html_parser(login.url)}</code>"

        if login.forward_text
            reenvío = html_parser(login.forward_text)
            texto << "#{tab2} Texto reenviado: <code>#{reenvío}</code>"
        end

        if login.bot_username
            texto << "#{tab2} Alias del bot: <code>#{login.bot_username}</code>"
        end

        return if login.request_write_access.nil?

        texto << "#{tab2} ¿Puedo escribirle al usuario?: "\
                 "<code>#{login.request_write_access ? 'Sí' : 'No'}</code>"
    end

    def crear_tab(profundidad, formato: true)
        tab = "\n"
        tab << '<code>' if formato

        profundidad.times do
            tab << "\t\t"
        end

        tab << '</code>' if formato
        tab << ' -'
    end
end
