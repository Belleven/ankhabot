class Dankie
    add_handler CommandHandler.new(:apodar, :setnickname,
                                   description: 'Te cambio el apodo al que me digas (si sos admin, podés cambiárselo a otros)')
    add_handler CommandHandler.new(:vos, :getinfo,
                                   description: 'Devuelve tu información (o la del usuario al que le respondas)')

    def setnickname(msg)
        new_nick = get_command_params(msg)
        if new_nick.nil? || (user == '')
            err_txt = "Si no me pasás un apodo, está jodida la cosa #{TROESMAS.sample}."
            @tg.send_message(chat_id: msg.chat.id,
                             reply_to_message: msg.message_id,
                             text: err_txt)
            return
        end

        user_id = msg.from.id
        chat_id = msg.chat.id
        firstname = msg.from.first_name
        lastname = msg.from.last_name
        reply_tgt = msg.message_id
        if sent_from_admin(user_id, chat_id)
            user_id = msg.reply_to_message ? msg.reply_to_message.from.id : msg.from.id
            firstname = msg.reply_to_message ? msg.reply_to_message.from.first_name : msg.from.first_name
            lastname = msg.reply_to_message ? msg.reply_to_message.from.last_name : msg.from.last_name
            reply_tgt = msg.reply_to_message ? msg.reply_to_message.message_id : msg.message_id
        end
        fullname = firstname
        if !lastname.nil? && !lastname.to_s.strip.empty?
            fullname << " #{lastname}"
        end
        @redis.set("userNick:#{"#{chat_id}-#{user_id}"}", new_nick)
        @redis.bgsave
        troesma = TROESMAS.sample
        print(troesma)
        txt_done = "De hoy en adelante, el #{troesma} '#{fullname}' será conocido como '#{new_nick}'."
        @tg.send_message(chat_id: msg.chat.id,
                         reply_to_message: reply_tgt,
                         text: txt_done)
    end

    def getinfo(msg)
        user_id = msg.reply_to_message ? msg.reply_to_message.from.id : msg.from.id
        chat_id = msg.chat.id
        firstname = msg.reply_to_message ? msg.reply_to_message.from.first_name : msg.from.first_name
        lastname = msg.reply_to_message ? msg.reply_to_message.from.last_name : msg.from.last_name

        fullname = firstname
        if !lastname.nil? && !lastname.to_s.strip.empty?
            fullname << " #{lastname}"
        end
        username = msg.reply_to_message ? msg.reply_to_message.from.username : msg.from.username
        lastfm = @redis.get("LastFM:#{user_id}")
        nick = @redis.get("Apodo:#{"#{chat_id}-#{user_id}"}")
        answer = fullname.nil? || fullname.to_s.strip.empty? ? "<b>Cuenta Eliminada</b>\n" : "Nombre de usuario: <b>#{html_parser(fullname)}</b>\n"
        answer << (username.nil? ? '' : "Alias: <b>#{html_parser(username)}</b>\n")
        answer << (user_id.nil? ? '' : "Id de usuario: #{html_parser(user_id)}\n")
        answer << (nick.nil? ? '' : "Apodo en el grupete: #{html_parser(nick)}\n")
        answer << (lastfm.nil? ? '' : "Cuenta de LastFM: #{html_parser(lastfm)}")

        @tg.send_message(chat_id: msg.chat.id,
                         reply_to_message: msg.message_id,
                         parse_mode: 'html',
                         text: answer)
    end
end

def sent_from_admin(user_id, chat_id)
    # Robada de Blacklist. En algún momento las sacaré a un utils
    member = @tg.get_chat_member(chat_id: chat_id, user_id: user_id)
    member = Telegram::Bot::Types::ChatMember.new(member['result'])
    status = member.status

    # Chequeo que quien llama al comando sea admin del grupete
    return false if (status != 'administrator') && (status != 'creator')

    true
end
