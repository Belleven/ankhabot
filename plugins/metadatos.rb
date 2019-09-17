class Dankie
    add_handler Handler::Comando.new(:metadatos, :metadatos, permitir_params: true,
                                                             descripción: 'Muestro los metadatos del '\
                                                  'mensaje respondido')

    def metadatos(msj, parámetros)
        # Si no responde a nada mando error
        if msj.reply_to_message.nil?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Respondele a un mensaje #{TROESMAS.sample}")
        else
        	# Me fijo si me piden que pase las entidades
            pasar_entidades = parámetros && /^--entidades[\s|\z]/i === parámetros

            # De ser así reviso que haya sido un dev pues puede floodear violentamente
            # mostras las entidades de un mensaje
            if pasar_entidades && !DEVS.include?(msj.chat.id)
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: msj.message_id,
                                 text: "Tenés que ser desarrollador "\
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

    private

    def agregar_datos_mensaje(msj, texto, pasar_entidades, nivel)
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

        # Agrego usuario
        if msj.from
            título = "\n\n - Enviado por: #{enlace_usuario_objeto(msj.from, msj.chat.id)}"
            agregar_usuario(texto, msj.from, título, nivel+1)
        end

        # Agrego chat
        agregar_chat(texto, msj.chat, "\n\n -Chat:", nivel+1)
        # Agregar info reenvío
        agregar_info_reenvío(texto, msj, nivel+1) if msj.forward_date
        # Agrego contenido del mensaje (texto, imágenes, etc)
        agregar_contenido(texto, msj, nivel+1, pasar_entidades)
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
            agregar_usuario(texto, msj.forward_from, título, nivel+1)
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
            agregar_chat(texto, msj.forward_from_chat, título, nivel+1)
        end
    end

    def agregar_contenido(respuesta, msj, nivel, pasar_entidades)
        # Agrego texto si hay
        agregar_texto(respuesta, 'Texto:', msj.text, msj.entities,
        			  nivel, pasar_entidades)

        # Otros
        agregar_audio(respuesta, msj.audio, nivel) if msj.audio
        agregar_documento(respuesta, msj.document, nivel) if msj.document
        agregar_animación(respuesta, msj.animation, nivel) if msj.animation
        agregar_juego(respuesta, msj.game, nivel) if msj.game
        agregar_imagen(respuesta, msj.photo, nivel) unless msj.photo.empty?
        agregar_sticker(respuesta, msj.sticker, nivel) if msj.sticker
        agregar_video(respuesta, msj.video, nivel) if msj.video
        agregar_msj_voz(respuesta, msj.voice, nivel) if msj.voice
        agregar_nota_video(respuesta, msj.video_note, nivel) if msj.video_note
        agregar_contacto(respuesta, msj.contact, nivel) if msj.contact
        agregar_ubicación(respuesta, msj.location, nivel) if msj.location
        agregar_venue(respuesta, msj.venue, nivel) if msj.venue
        agregar_encuesta(respuesta, msj.poll, nivel) if msj.poll
        agregar_pasaporte(respuesta, msj.passport_data, nivel) if msj.passport_data
        agregar_botones(respuesta, msj.reply_markup, nivel) if msj.reply_markup      
        agregar_pago(respuesta, msj.successful_payment, nivel) if msj.successful_payment

        # Agrego caption si hay
        agregar_texto(respuesta, 'Epígrafe:', msj.caption, msj.caption_entities,
        			   nivel, pasar_entidades)

        # Me fijo si hay eventos de chat
        agregar_eventos_chat(respuesta, msj, nivel)
    end

    def agregar_texto(respuesta, título, texto_msj, entidades, nivel, pasar_entidades)
        return unless texto_msj
        long = texto_msj.length

        # Agrego el texto
        texto_msj = (texto_msj[0..200] + '...') if long > 200
        respuesta << "\n\n - #{título}<code> #{html_parser(texto_msj)}</code>"
        respuesta << "\n - Longitud:<code> #{long}</code>"

        # Agrego las entidades
        unless entidades.empty?
            respuesta << "\n - Entidades del #{título.downcase}"\
                     "<code> #{entidades.length}</code>"

            return unless pasar_entidades
            # Creo tabs
            tab1 = crear_tab(nivel)
            tab2 = crear_tab(nivel+1)

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
                agregar_usuario(respuesta, entidad.user, título, nivel+2)
            end
        end
    end

    def agregar_audio(texto, audio, nivel)
        tab = crear_tab(nivel)

        # Agrego datos que seguro aparecen
        texto << "\n\n - Audio:"\
                 "#{tab} ID:<code> #{audio.file_id}</code>"\
                 "#{tab} Duración:<code> #{audio.duration}</code>"

        # Agrego datos opcionales
        texto << "#{tab} Artista:<code> #{audio.performer}</code>" if audio.performer
        texto << "#{tab} Título:<code> #{audio.title}</code>" if audio.title
        texto << "#{tab} MIME:<code> #{audio.mime_type}</code>" if audio.mime_type
        texto << "#{tab} Tamaño:<code> #{audio.file_size} bytes</code>" if audio.file_size

        # Agrego miniatura si tiene
        agregar_miniatura(texto, audio.thumb, nivel) if audio.thumb
    end

    def agregar_documento(texto, documento, nivel); end

    def agregar_animación(texto, animación, nivel); end

    def agregar_juego(texto, game, nivel); end

    def agregar_imagen(texto, imagenes, nivel); end

    def agregar_sticker(texto, sticker, nivel); end

    def agregar_video(texto, video, nivel); end

    def agregar_msj_voz(texto, msj_voz, nivel); end

    def agregar_nota_video(texto, nota_video, nivel); end

    def agregar_contacto(texto, contacto, nivel); end

    def agregar_ubicación(texto, ubicación, nivel); end

    def agregar_venue(texto, venue, nivel); end

    def agregar_encuesta(texto, encuesta, nivel); end

    def agregar_pago(texto, pago_exitoso, nivel); end

    def agregar_pasaporte(texto, data_pasaporte, nivel); end

    def agregar_botones(texto, tablero, nivel); end

    def agregar_eventos_chat(texto, msj, nivel); end


    def agregar_miniatura(texto, miniatura, nivel)
    	# Creo tabs
    	tab1 = crear_tab(nivel)
    	tab2 = crear_tab(nivel+1)

    	# Agrego miniatura
    	texto << "#{tab1} Miniatura:"
    			 	
    	# Agrego datos miniatura
    	texto << "#{tab2} ID:<code> #{miniatura.file_id}</code>"\
    			 "#{tab2} Ancho:<code> #{miniatura.width}</code>"\
    			 "#{tab2} Alto:<code> #{miniatura.height}</code>"

    	# Dato opcional
    	if miniatura.file_size
    		texto << "#{tab2} Tamaño:<code> #{miniatura.file_size}</code>"
    	end
    end

    def crear_tab(profundidad)
        tab = "\n<code>"
        profundidad.times do
            tab << "\t\t"
        end
        tab << '</code> -'
    end
end
