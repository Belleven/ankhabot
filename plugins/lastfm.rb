class Dankie
    add_handler Handler::Comando.new(:guardarlastfm, :guardar_lastfm, permitir_params: true,
                                                                      descripción: 'Guarda tu usuario de Last.Fm '\
                                                  '(Solo necesita tu usuario)')
    add_handler Handler::Comando.new(:verlastfm, :ver_lastfm,
                                     descripción: 'Devuelve la información '\
                                                  'registrada de Last.Fm del '\
                                                  'usuario')
    add_handler Handler::Comando.new(:escuchando, :escuchando,
                                     descripción: 'Devuelve la canción más '\
                                                  'reciente que escucha el '\
                                                  'usuario que te pusiste')
    add_handler Handler::Comando.new(:fmrecientes, :fm_recientes, permitir_params: true,
                                                                  descripción: 'Devuelve las últimas '\
                                                  'canciones que escuchaste. '\
                                                  'Pasame un número así te paso '\
                                                  'más de 1 canción (máx 15).')

    def guardar_lastfm(msj, usuario)
        return unless hay_usuario(usuario)

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

    def fm_recientes(msj, cantidad)
        cantidad = natural(cantidad)

        if !cantidad
            cantidad = 0
        elsif cantidad > 15
            cantidad = 15
        end

        usuario = @redis.get("lastfm:#{msj.from.id}")
        return unless hay_usuario(usuario)

        ahora_escuchando = @lastFM.now_playing usuario, cantidad
        return unless validar_pistas(msj, ahora_escuchando)

        texto = "Canciones recientes del usuario: \n\n"
        ahora_escuchando.each do |pista, índice|
            texto << "<b>#{índice}.</b> #{html_parser(pista['artist']['#text'])} "\
                     "- <b>#{html_parser(pista['name'])}</b> "\
                     "[#{html_parser(pista['album']['#text'])}]\n"
        end
        @tg.send_message(chat_id: msj.chat.id,
                         parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         text: texto)
    end

    def escuchando(msj)
        usuario = @redis.get("lastfm:#{msj.from.id}")
        return unless hay_usuario(usuario)

        temazo = @lastFM.now_playing usuario, 1
        return unless validar_pistas(msj, temazo)

        texto = "Mirate este temón: \n"\
                "👤: #{html_parser(temazo.first['artist']['#text'])}\n"\
                "🎵: #{html_parser(temazo.first['name'])}\n"\
                "💿: #{html_parser(temazo.first['album']['#text'])}"\
                "<a href=\"#{html_parser(temazo.first['image'][2]['#text'])}\">\u200d</a>"
        @tg.send_message(chat_id: msj.chat.id,
                         parse_mode: :html,
                         reply_to_message_id: msj.message_id,
                         text: texto)
    end

    private

    def hay_usuario(usuario)
        if (hay = usuario.nil? || usuario.empty?)
            err_txt = "Si no me pasás un usuario, está jodida la cosa #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id,
                             text: err_txt,
                             reply_to_message_id: msj.message_id)
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
                             text: "Alto error #{TROESMAS.sample}. "\
                                   "\n<b>#{arr[1]}</b>")
            return false
        end
        true
    end
end
