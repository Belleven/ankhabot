require 'telegram/bot'

class Dankie
    command trinsfirmir: 'Convierte un texto a isti firmiti'

    def trinsfirmir(msg)
        return unless msg.is_a?(Telegram::Bot::Types::Message)

        cmd = parse_command(msg)
        return unless cmd && (cmd[:command] == :trinsfirmir)

        unless (text = msg&.reply_to_message&.text || msg&.reply_to_message&.caption)
            text = "Respondele a algo, #{TROESMAS.sample}."
            send_message(chat_id: msg.chat.id,
                         text: text)
            return
        end

        text.gsub!(/[aeiou]/, 'i')
        text.gsub!(/[AEIOU]/, 'I')
        text.gsub!(/[áéíóú]/, 'í')
        text.gsub!(/[ÁÉÍÓÚ]/, 'Í')

        send_message(chat_id: msg.chat.id,
                     text: text)
        send_sticker(chat_id: msg.chat.id,
                     sticker: 'BQADAgADQQEAAksODwABJlVW31Lsf6sC')
    end
end
