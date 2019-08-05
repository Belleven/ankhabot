require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(:trinsfirmir, :trinsfirmir,
                                     descripción: 'Convierte un texto a isti '\
                                                  'firmiti')

    def trinsfirmir(msj)
        unless (text = msj&.reply_to_message&.text || msj&.reply_to_message&.caption)
            text = "Respondele a algo que tenga texto, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id, text: text)
            return
        end

        text.gsub!(/[aeiou]/, 'i')
        text.gsub!(/[AEIOU]/, 'I')
        text.gsub!(/[áéíóú]/, 'í')
        text.gsub!(/[ÁÉÍÓÚ]/, 'Í')

        @tg.send_message(chat_id: msj.chat.id, text: text)
        @tg.send_sticker(chat_id: msj.chat.id, sticker: 'BQADAgADQQEAAksODwABJlVW31Lsf6sC')
    end
end
