class Dankie
    add_handler Handler::Comando.new(:usuariolastfm, :usuario_last_fm,
                                     permitir_params: true,
                                     descripción: 'Guardo o muestro tu '\
                                                  'usuario de last.fm')
    add_handler Handler::Comando.new(:borrarlastfm, :borrar_usuario_last_fm,
                                     descripción: 'Borro tu usuario de last.fm')
    add_handler Handler::Comando.new(:escuchando, :escuchando, permitir_params: true,
                                                               descripción: 'Lo que estás escuchando ahora o '\
                                                  'lo último que escuchaste.')
    add_handler Handler::Comando.new(:recientes, :recientes, permitir_params: true,
                                                             descripción: 'Lista de los últimos temas que '\
                                                  'escuchaste')

    def usuario_last_fm(msj, params)
        # Sin parámetros mando la info actual.
        unless params
            if (usuario = @redis.get("lastfm:#{msj.from.id}"))
                @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                                 reply_to_message_id: msj.message_id,
                                 text: 'Tu usuario de Last.fm es '\
                                       "<code>#{html_parser usuario}</code>.")
            else
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: msj.message_id,
                                 text: "Configurá tu usuario con \n"\
                                       '/usuariolastfm mi_usuario')
            end
            return
        end

        # Si hay parámetros, sobreescribo la cuenta actual.
        usuario = @lastfm.user.get_info user: params

        unless usuario
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "Pasame bien un usuario, #{TROESMAS.sample}.")
            return
        end

        @redis.set "lastfm:#{msj.from.id}", params

        texto = "Listo, #{TROESMAS.sample}. Tu usuario ahora es "
        texto << "<code>#{html_parser usuario.dig('user', 'name')}</code>."
        @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                         parse_mode: :html, text: texto)
    rescue StandardError => e
        logger.error e.to_s
        @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                         text: 'Saltó un error, probablemente pusiste mal tu usuario.')
    end

    def borrar_usuario_last_fm(msj)
        if @redis.del("lastfm:#{msj.from.id}").zero?
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: 'No pude borrar nada. Capaz no '\
                             'tenías tu cuenta puesta.')
        else
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "Ya borré tu cuenta, #{TROESMAS.sample}.")
        end
    end

    def escuchando(msj, args)
        unless (usuario = args || @redis.get("lastfm:#{msj.from.id}"))
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: 'Si no me pasás un usuario, está jodida la cosa, '\
                             "#{TROESMAS.sample}.")
            return
        end

        @logger.info "Pidiendo el tema que está escuchando #{usuario}"

        temazo = @lastfm.user.get_recent_tracks(user: usuario, limit: 1)

        # Capaz que esto despues sea validado como una excepción.
        unless temazo
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: 'Me tiró error, ¿Pusiste bien el usuario?')
            return
        end

        # Si no escuchó ningún tema.
        if temazo.dig('recenttracks', '@attr', 'total').to_i.zero?
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "No escuchaste nada, #{TROESMAS.sample}.")
            return
        end

        # El primer tema.
        temazo = temazo.dig 'recenttracks', 'track', 0

        # Primero pongo el link invisible así lo toma para la preview.
        imágen = temazo.dig('image', -1, '#text')
        imágen = imágen.empty? ? 'https://i.imgur.com/fwu2ESz.png' : imágen
        texto = '<a href="' << html_parser(imágen) << '">' << "\u200d</a>"

        texto << (args || obtener_enlace_usuario(msj.from.id, msj.chat.id))
        texto << if temazo.dig('@attr', 'nowplaying')
                     " está escuchando\n\n"
                 else
                     " estuvo escuchando\n\n"
                 end
        texto << datos_tema(temazo)

        @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                         parse_mode: :html, text: texto)
    rescue StandardError => e
        logger.error e.to_s
        @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                         text: 'Saltó un error, probablemente pusiste mal tu usuario.')
    end

    def recientes(msj, args)
        if args && (args.match?(/\D+/) || args.to_i.zero?)
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "Pasame un número natural, #{TROESMAS.sample}.")
            return
        end
        cantidad = [args ? args.to_i : 5, 15].min # Si no recibe args, toma 5

        unless (usuario = @redis.get "lastfm:#{msj.from.id}")
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: 'Si no me pasás un usuario, está jodida la cosa, '\
                                   "#{TROESMAS.sample}.")
            return
        end

        @logger.info "#{usuario} pidió #{cantidad} temas recientes"
        temas = @lastfm.user.get_recent_tracks(user: usuario, limit: cantidad)
        unless temas
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: 'Me tiró error, ¿Pusiste bien el usuario?')
            return
        end

        temas = temas.dig 'recenttracks', 'track'
        temas.pop if temas.size > cantidad # Bug que manda un tema mas que lo pedido

        escuchando = temas.find { |tema| tema.dig('@attr', 'nowplaying') }
        temas.delete(escuchando)

        if temas.empty? && escuchando.nil?
            @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                             text: "No escuchaste ningún tema, #{TROESMAS.sample}.")
            return
        end

        texto = 'Canciones recientes de '
        texto << "#{obtener_enlace_usuario(msj.from.id, msj.chat.id)}:\n\n"

        if escuchando
            texto << '<code>' << (temas.size > 9 ? '01.' : '1.') << '</code> '
            texto << datos_tema_compacto(escuchando) << " <i>(ahora)</i>\n"

            # despues veo si es verdad eso de que a veces el primer tema es el que suena
        end

        # Si ya puse un tema, arranco del 2
        índice = escuchando ? 2 : 1

        temas.each do |tema|
            texto << '<code>' << (temas.size > 9 && índice < 10 ? '0' : '')
            texto << índice.to_s << '.</code> '
            texto << datos_tema_compacto(tema) << "\n"
            índice += 1
        end

        @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                         disable_web_page_preview: true, parse_mode: :html, text: texto)
    rescue StandardError => e
        logger.error e.to_s
        @tg.send_message(chat_id: msj.chat.id, reply_to_message_id: msj.message_id,
                         text: 'Saltó un error, probablemente pusiste mal tu usuario.')
    end

    private

    # Función que recibe un hash del arreglo de 'track' que devuelve la api y devuelve
    # un String.
    def datos_tema(tema)
        texto = "\u{1F3B5} "

        texto << if (nombre = tema.dig('name')) && !nombre.empty?
                     html_parser nombre
                 else
                     'Sin nombre'
                 end

        texto << if (álbum = tema.dig('album', '#text')) && !álbum.empty?
                     "\n\u{1F4BF} #{html_parser álbum}"
                 else
                     ''
                 end

        texto << "\n\u{1F464} "
        texto << if (artista = tema.dig('artist', '#text')) && !artista.empty?
                     html_parser artista
                 else
                     'Sin artista'
                 end
    end

    def datos_tema_compacto(tema)
        texto = ''

        texto << if (nombre = tema.dig('name')) && !nombre.empty?
                     nombre
                 else
                     'Sin nombre'
                 end

        texto << if (artista = tema.dig('artist', '#text')) && !artista.empty?
                     " - <b>#{html_parser artista}</b>"
                 else
                     'Sin artista'
                 end

        texto << if (álbum = tema.dig('album', '#text')) && !álbum.empty?
                     " (#{html_parser álbum})"
                 else
                     ''
                 end

        texto
    end
end
