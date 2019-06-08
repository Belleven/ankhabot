require 'telegram/bot'

class Dankie
    add_handler CommandHandler.new(:trinsfirmir, :trinsfirmir,
                                   description: 'Convierte un texto a isti '\
                                                'firmiti')

    def trinsfirmir(msg)
        unless (text = msg&.reply_to_message&.text || msg&.reply_to_message&.caption)
            text = "Respondele a algo que tenga texto, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msg.chat.id, text: text)
            return
        end

        text.gsub!(/[aeiou]/, 'i')
        text.gsub!(/[AEIOU]/, 'I')
        text.gsub!(/[áéíóú]/, 'í')
        text.gsub!(/[ÁÉÍÓÚ]/, 'Í')

        @tg.send_message(chat_id: msg.chat.id,
                         text: text)
        @tg.send_sticker(chat_id: msg.chat.id,
                         sticker: 'BQADAgADQQEAAksODwABJlVW31Lsf6sC')
    end
end
