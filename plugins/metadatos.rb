class Dankie
    add_handler Handler::Comando.new(:metadatos, :metadatos, permitir_params: true,
                                                             descripción: 'Muestro los metadatos del '\
                                                  'mensaje respondido')

    def metadatos(msj, parámetros)
        if msj.reply_to_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Respondele a un mensaje #{TROESMAS.sample}")
        else
            pasar_entidades = parámetros && /^--entidades[\s|$]/i === parámetros

            if pasar_entidades && !DEVS.include?(msj.chat.id)
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: msj.message_id,
                                 text: 'Tenés que ser desarrollador '\
                                   "para eso #{TROESMAS.sample}")
                return
            end

            msj_datos = msj.reply_to_message

            texto = "<b>Metadatos del mensaje:</b>\n"
            agregar_datos_mensaje(msj_datos, texto, pasar_entidades)

            @tg.send_message(chat_id: msj.chat.id,
                             parse_mode: :html,
                             text: texto,
                             disable_web_page_preview: true,
                             disable_notification: true)
        end
    end

    private

    def agregar_datos_mensaje(msj, texto, pasar_entidades)
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
        texto << "\n - Autor: #{msj.author_signature}" if msj.author_signature

        # Armo un ''tab'' para después acomodar el texto
        tab = "\n<code>\t\t</code> -"
        doble_tab = "\n<code>\t\t\t\t</code> -"
        # Agrego usuario
        if msj.from
            título = "\n\n - Enviado por: #{enlace_usuario_objeto(msj.from, msj.chat.id)}"
            agregar_usuario(texto, msj.from, título, tab)
        end

        # Agrego chat
        agregar_chat(texto, msj.chat, "\n\n -Chat:", tab)
        # Agregar info reenvío
        agregar_info_reenvío(texto, msj, tab, doble_tab) if msj.forward_date
        # Agrego contenido del mensaje (texto, imágenes, etc)
        agregar_contenido(texto, msj, tab, doble_tab, pasar_entidades)
    end

    def agregar_usuario(texto, usuario, título, tab)
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
            agregar_nombres(texto, usuario, tab)

            # Código de lenguaje si tiene
            if usuario.language_code
                texto << "#{tab} Código de lenguaje:"\
                         "<code> #{usuario.language_code}</code>"
            end
        end
    end

    def agregar_chat(texto, chat, título, tab)
        # Agrego id y tipo
        texto << "#{título}"\
                 "#{tab} ID:<code> #{chat.id}</code>"\
                 "#{tab} Tipo:<code> #{chat.type}</code>"

        # Agrego título si tiene, si no info del chat privado
        texto << "#{tab} Título:<code> #{html_parser(chat.title)}</code>" if chat.title
        # Agrego nombre, apellido y alias si hay
        agregar_nombres(texto, chat, tab)
    end

    def agregar_nombres(texto, elemento, tab)
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

    def agregar_info_reenvío(texto, msj, tab, doble_tab)
        # Obtengo fecha
        fecha_reenvío = Time.at(msj.forward_date, in: @tz.utc_offset).to_datetime
        fecha_reenvío = fecha_reenvío.strftime('%d/%m/%Y %T %Z')

        # Pongo título y fecha original de envío
        texto << "\n\n- Información de reenvío:"\
                 "#{tab} Fecha envío original:<code> #{fecha_reenvío}</code>"

        # Info del usuario original
        if msj.forward_from
            texto << "#{tab} Cuenta oculta:<code> No</code>"
            título = "#{tab} Reenviado de: #{enlace_usuario_objeto(msj.forward_from, msj.chat.id)}"
            agregar_usuario(texto, msj.forward_from, título, doble_tab)
        elsif msj.forward_sender_name
            # Si es una cuenta oculta
            texto << "#{tab} Cuenta oculta:<code> Sí</code>"
            texto << "#{tab} Nombre:<code> #{html_parser(msj.forward_sender_name)}</code>"
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
            agregar_chat(texto, msj.forward_from_chat, título, doble_tab)
        end
    end

    def agregar_contenido(texto, msj, tab, doble_tab, pasar_entidades)
        # Agrego texto si hay
        agregar_texto(texto, 'Texto:', msj.text, msj.entities, tab,
                      doble_tab, pasar_entidades)

        # Otros
        agregar_audio(texto, msj.audio, tab, doble_tab) if msj.audio
        agregar_documento(texto, msj.document, tab, doble_tab) if msj.document
        agregar_animación(texto, msj.animation, tab, doble_tab) if msj.animation
        agregar_juego(texto, msj.game, tab, doble_tab) if msj.game
        agregar_imagen(texto, msj.photo, tab, doble_tab) unless msj.photo.empty?
        agregar_sticker(texto, msj.sticker, tab, doble_tab) if msj.sticker
        agregar_video(texto, msj.video, tab, doble_tab) if msj.video
        agregar_msj_voz(texto, msj.voice, tab, doble_tab) if msj.voice
        agregar_nota_video(texto, msj.video_note, tab, doble_tab) if msj.video_note
        agregar_contacto(texto, msj.contact, tab, doble_tab) if msj.contact
        agregar_ubicación(texto, msj.location, tab, doble_tab) if msj.location
        agregar_venue(texto, msj.venue, tab, doble_tab) if msj.venue
        agregar_encuesta(texto, msj.poll, tab, doble_tab) if msj.poll
        agregar_pasaporte(texto, msj.passport_data, tab, doble_tab) if msj.passport_data
        agregar_botones(texto, msj.reply_markup, tab, doble_tab) if msj.reply_markup
        if msj.successful_payment
            agregar_pago_realizado(texto, msj.successful_payment,
                                   tab, doble_tab)
        end

        # Agrego caption si hay
        # agregar_texto(texto, 'Epígrafe:', msj.caption,
        #              msj.caption_entities, tab, doble_tab, pasar_entidades)

        # Me fijo si hay eventos de chat
        agregar_eventos_chat(texto, msj, tab, doble_tab)
    end

    def agregar_texto(texto, título, texto_msj, entidades, tab,
                      doble_tab, pasar_entidades)
        return unless texto_msj

        long = texto_msj.length

        # Agrego el texto
        texto_msj = (texto_msj[0..200] + '...') if long > 200
        texto << "\n\n - #{título}<code> #{html_parser(texto_msj)}</code>"
        texto << "\n - Longitud:<code> #{long}</code>"

        # Agrego las entidades
        unless entidades.empty?
            texto << "\n - Entidades del #{título.downcase}"\
                     "<code> #{entidades.length}</code>"

            return unless pasar_entidades

            entidades.each_with_index do |entidad, índice|
                # Nro entidad
                texto << "#{tab} Entidad <b>#{índice + 1}</b>:"\
                         "#{doble_tab} Tipo:<code> #{entidad.type}</code>"\
                         "#{doble_tab} Desfasaje:<code> #{entidad.offset}</code>"\
                         "#{doble_tab} Longitud:<code> #{entidad.length}</code>"

                if entidad.url
                    texto << "#{doble_tab} Enlace:<code> "\
                             "#{html_parser(entidad.url)}</code>"
                end

                next unless entidad.user

                triple_tab = "\n<code>\t\t\t\t\t\t</code> -"
                título = "#{doble_tab} Usuario mencionado:"
                agregar_usuario(texto, entidad.user, título, triple_tab)
            end
        end
    end

    def agregar_audio(texto, _audio, _tab, _doble_tab)
        texto << "\n\n - Audio:"\
                 ''
    end

    def agregar_documento(texto, documento, tab, doble_tab); end

    def agregar_animación(texto, animación, tab, doble_tab); end

    def agregar_juego(texto, game, tab, doble_tab); end

    def agregar_imagen(texto, imagenes, tab, doble_tab); end

    def agregar_sticker(texto, sticker, tab, doble_tab); end

    def agregar_video(texto, video, tab, doble_tab); end

    def agregar_msj_voz(texto, msj_voz, tab, doble_tab); end

    def agregar_nota_video(texto, nota_video, tab, doble_tab); end

    def agregar_contacto(texto, contacto, tab, doble_tab); end

    def agregar_ubicación(texto, ubicación, tab, doble_tab); end

    def agregar_venue(texto, venue, tab, doble_tab); end

    def agregar_encuesta(texto, encuesta, tab, doble_tab); end

    def agregar_pago_realizado(texto, pago_exitoso, tab, doble_tab); end

    def agregar_pasaporte(texto, data_pasaporte, tab, doble_tab); end

    def agregar_botones(texto, tablero, tab, doble_tab); end

    def agregar_eventos_chat(texto, msj, tab, doble_tab); end

    def crear_tab(profundidad)
        tab = "\n<code>"

        profundidad.times.each do |_índice|
            tab << "\t\t"
        end

        tab << '</code> -'
        tab
    end
end
