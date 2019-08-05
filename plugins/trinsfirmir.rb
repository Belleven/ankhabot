require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(:trinsfirmir, :trinsfirmir,
                                     descripción: 'Convierte un texto a isti '\
                                                  'firmiti')

    def trinsfirmir(msj)
        unless (texto = msj&.reply_to_message&.text || msj&.reply_to_message&.caption)
            texto = "Respondele a algo que tenga texto, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id, text: texto)
            return
        end

        texto.gsub!(/[aeouäëöüâêôûàèòù]/, 'i')
        texto.gsub!(/[AEOUÄËÖÜÂÊÔÛÀÈÒÙ]/, 'I')
        texto.gsub!(/[áéóú]/, 'í')
        texto.gsub!(/[ÁÉÓÚ]/, 'Í')

        @tg.send_message(chat_id: msj.chat.id,
                         text: texto)
        @tg.send_sticker(chat_id: msj.chat.id,
                         sticker: 'BQADAgADQQEAAksODwABJlVW31Lsf6sC')
    end
end
