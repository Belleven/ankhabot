require 'telegram/bot'

class Dankie
    add_handler CommandHandler.new(:recarga, :recarga,
                                   description: 'Recarga la bala y gira la '\
                                                'ruleta (6 ranuras)')
    add_handler CommandHandler.new(:dispara, :dispara,
                                   description: 'Dispara la próxima bala')
    @@juegos = {}

    def recarga(msj)
        @@juegos[msj.chat.id] ||= [0, []]
        cant_balas, balas_arr = @@juegos[msj.chat.id]
        cant_balas += 1 if cant_balas < 6

        balas_arr = Array.new(cant_balas, true)
        (6 - cant_balas).times { balas_arr.push(false) }
        balas_arr = balas_arr.shuffle
        @@juegos[msj.chat.id] = [cant_balas, balas_arr]

        text = 'Recargado y girado. Hay ' + cant_balas.to_s + " balas de 6 cargadas en la bersa.\n"

        @tg.send_message(chat_id: msj.chat.id,
                         reply_to_message_id: msj&.reply_to_message&.message_id,
                         text: text)
    end

    def dispara(msj)
        if @@juegos[msj.chat.id].nil?
            text = "Si no recargas no te puedo Nismanear #{TROESMAS.sample}. \n"
        else
            juego_actual = @@juegos[msj.chat.id]
            val = juego_actual[1].shift
            if val
                juego_actual[0] -= 1
                text = "Te Nismaneaste #{TROESMAS.sample}. \n"
            else
                text = "Sobreviviste #{TROESMAS.sample}.\n"
            end

            if juego_actual[0] == 0
                text << "Se acabaron las balas. Vuelvan a recargar. \n"
                @@juegos.delete(msj.chat.id)
            else
                text << 'Balas restantes: ' + juego_actual[0].to_s + "\n"
                text << 'Tiros restantes: ' + juego_actual[1].length.to_s + "\n"
            end

        end

        @tg.send_message(chat_id: msj.chat.id, text: text)
    end
end
