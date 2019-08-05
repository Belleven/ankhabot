class Dankie
    add_handler Handler::Comando.new(:guardarlastfm, :setlastfm,
                                     descripción: 'Guarda tu usuario de Last.Fm '\
                                                  '(Solo necesita tu usuario)')
    add_handler Handler::Comando.new(:verlastfm, :getlastfm,
                                     descripción: 'Devuelve la información '\
                                                  'registrada de Last.Fm del '\
                                                  'usuario')
    add_handler Handler::Comando.new(:escuchando, :nowplaying,
                                     descripción: 'Devuelve la canción más '\
                                                  'reciente que escucha el '\
                                                  'usuario que te pusiste')
    add_handler Handler::Comando.new(:fmrecientes, :recentplayed,
                                     descripción: 'Devuelve las últimas '\
                                                  'canciones que escuchaste. '\
                                                  'Pasame un número así te paso '\
                                                  'más de 1 canción (máx 15).')

    def setlastfm(msj)
        user = get_command_params(msj)

        if user.nil? || (user == '')
            err_txt = "Si no me pasás un usuario, está jodida la cosa #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: err_txt)
            return
        end

        user_id = msj.from.id
        @redis.set("lastfm:#{user_id}", user)
        @redis.bgsave
        txt_done = "Listo #{TROESMAS.sample}. Tu usuario de Last.fm ahora es '#{user}'."
        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         text: txt_done)
    end

    def getlastfm(msj)
        user_id = msj.from.id
        user = @redis.get("lastfm:#{user_id}")
        txt_done = "Por el momento, tu usuario de Last.fm es '#{user}'."
        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj.message_id,
                         text: txt_done)
    end

    def recentplayed(msj)
        amount = get_command_params(msj).to_i

        amount = 1 if amount <= 0

        amount = 15 if amount > 15
        user_id = msj.from.id
        user = @redis.get("lastfm:#{user_id}")

        if user.nil? || (user == '')
            err_txt = "Si no te seteás un usuario, está jodida la cosa #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: err_txt)
            return
        end

        np = @lastFM.now_playing user, amount

        valid = valid_recent_tracks(msj, np)
        return unless valid

        out = "Canciones recientes del usuario: \n\n"
        x = 0
        np.each do |track|
            x += 1
            out += "<b>#{x}.</b> #{track['artist']['#text']} - <b>#{track['name']}</b> [#{track['album']['#text']}]\n"
        end
        @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html',
                         reply_to_message_id: msj.message_id,
                         text: out)
    end

    def nowplaying(msj)
        user_id = msj.from.id
        user = @redis.get("lastfm:#{user_id}")

        if user.nil? || (user == '')
            err_txt = "Si no te seteás un usuario, está jodida la cosa #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: err_txt)
            return
        end

        np = @lastFM.now_playing user, 1

        valid = valid_recent_tracks(msj, np)
        return unless valid

        out = "Mirate este temón: \n"
        out << "👤: #{np[0]['artist']['#text']}\n"
        out << "🎵: #{np[0]['name']}\n"
        out << "💿: #{np[0]['album']['#text']}"
        out << "<a href=\"#{np[0]['image'][2]['#text']}\">\u200d</a>"

        @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html',
                         reply_to_message_id: msj.message_id,
                         text: out)
    end

    def valid_recent_tracks(msj, arr)
        if arr.empty?
            @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html',
                             reply_to_message_id: msj.message_id,
                             text: "No encontré que hayas escuchado ninguna canción #{TROESMAS.sample}.")
            return false
        elsif arr[0] == 'error'
            @tg.send_message(chat_id: msj.chat.id, parse_mode: 'html',
                             reply_to_message_id: msj.message_id,
                             text: "Alto error #{TROESMAS.sample}. \n<b>#{arr[1]}</b>")
            return false
        end
        true
    end
end
