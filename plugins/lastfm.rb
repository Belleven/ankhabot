class Dankie
    add_handler CommandHandler.new(:setlastfm, :setlastfm,
                                   description: 'Guarda tu usuario de Last.Fm '\
                                                '(Solo necesita tu usuario)')
    add_handler CommandHandler.new(:getlastfm, :getlastfm,
                                   description: 'Devuelve la información '\
                                                'registrada de Last.Fm del '\
                                                'usuario')
    add_handler CommandHandler.new(:nowplaying, :nowplaying,
                                   description: 'Devuelve la canción más '\
                                                'reciente que escucha el '\
                                                'usuario que te pusiste')
    add_handler CommandHandler.new(:recentplayed, :recentplayed,
                                   description: 'Devuelve las últimas '\
                                                'canciones que escuchaste. '\
                                                'Pasame un número así te paso '\
                                                'más de 1 canción (máx 15).')

    def setlastfm(msg)
        user = get_command_params(msg)

        if user.nil? || (user == '')
            err_txt = "Si no me pasás un usuario, está jodida la cosa #{TROESMAS.sample}."
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: err_txt)
            return
        end

        user_id = msg.from.id
        @redis.set("LastFM:#{user_id}", user)
        @redis.bgsave
        txt_done = "Listo #{TROESMAS.sample}. Tu usuario de Last.fm ahora es '#{user}'."
        @tg.send_message(chat_id: msg.chat.id,
                         reply_to_message: msg.message_id,
                         text: txt_done)
    end

    def getlastfm(msg)
        user_id = msg.from.id
        user = @redis.get("LastFM:#{user_id}")
        txt_done = "Por el momento, tu usuario de Last.fm es '#{user}'."
        @tg.send_message(chat_id: msg.chat.id,
                         reply_to_message: msg.message_id,
                         text: txt_done)
    end

    def recentplayed(msg)
        amount = get_command_params(msg).to_i

        amount = 1 if amount <= 0

        amount = 15 if amount > 15
        user_id = msg.from.id
        user = @redis.get("LastFM:#{user_id}")

        if user.nil? || (user == '')
            err_txt = "Si no te seteás un usuario, está jodida la cosa #{TROESMAS.sample}."
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: err_txt)
            return
        end

        np = @lastFM.now_playing user, amount

        valid = valid_recent_tracks(msg, np)
        return unless valid

        out = "Canciones recientes del usuario: \n\n"
        x = 0
        np.each do |track|
            x += 1
            out += "<b>#{x}.</b> #{track['artist']['#text']} - <b>#{track['name']}</b> [#{track['album']['#text']}]\n"
        end
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message: msg.message_id,
                         text: out)
    end

    def nowplaying(msg)
        user_id = msg.from.id
        user = @redis.get("LastFM:#{user_id}")

        if user.nil? || (user == '')
            err_txt = "Si no te seteás un usuario, está jodida la cosa #{TROESMAS.sample}."
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: err_txt)
            return
        end

        np = @lastFM.now_playing user, 1

        valid = valid_recent_tracks(msg, np)
        return unless valid

        out = "Mirate este temón: \n"
        out << "👤: #{np[0]['artist']['#text']}\n"
        out << "🎵: #{np[0]['name']}\n"
        out << "💿: #{np[0]['album']['#text']}"
        out << "<a href=\"#{np[0]['image'][2]['#text']}\">\u200d</a>"

        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                         reply_to_message: msg.message_id,
                         text: out)
    end

    def valid_recent_tracks(msg, arr)
        if arr.empty?
            @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                             reply_to_message: msg.message_id,
                             text: "No encontré que hayas escuchado ninguna canción #{TROESMAS.sample}.")
            return false
        elsif arr[0] == 'error'
            @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html',
                             reply_to_message: msg.message_id,
                             text: "Alto error #{TROESMAS.sample}. \n<b>#{arr[1]}</b>")
            return false
        end
        true
    end
end
