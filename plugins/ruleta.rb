require 'telegram/bot'

class Dankie
    command recarga: 'Recarga la bala y gira la ruleta (6 ranuras)'
    command dispara: 'Dispara la próxima bala'
    @@juegos = {}


    def ruleta(msg)
        return unless msg.is_a?(Telegram::Bot::Types::Message)

        cmd = parse_command(msg)
        return unless cmd

        if cmd[:command] == :recarga
            recarga(msg)
        elsif cmd[:command] == :dispara
            dispara(msg)
        end
    end

    private

    def recarga(msg)
        @@juegos[msg.chat.id] ||= [0, []]
        cant_balas, balas_arr = @@juegos[msg.chat.id]
        cant_balas += 1
        cant_balas = 6 if cant_balas > 6

        balas_arr = Array.new(cant_balas, true)
        (6 - cant_balas).times { cant_balas.push(false) }
        balas_arr = balas_arr.shuffle
        @@juegos[msg.chat.id] = [cant_balas, balas_arr]

        text = "Recargado y girado. Hay " + cant_balas.to_s + " balas de 6 cargadas en la bersa.\n"


        send_message(chat_id: msg.chat.id,
                     reply_to_message_id: msg&.reply_to_message&.message_id,
                     text: text)
    end

    def dispara(msg)
        if (@@juegos[msg.chat.id] == nil)
            text = "Si no recargas no te puedo Nismanear #{TROESMAS.sample}. \n"
        else
            cant_balas, balas_arr = @@juegos[msg.chat.id]
            val = balas_arr.shift
            if val
                cant_balas -= 1
                text = "Te Nismaneaste #{TROESMAS.sample}. \n"
            else
                text = "Sobreviviste #{TROESMAS.sample}.\n"
            end

            if cant_balas == 0
                text << "Se acabaron las balas. Vuelvan a recargar. \n"
                @@juegos.delete(msg.chat.id)
            else
                text << 'Balas restantes: ' + cant_balas.to_s + "\n"
                text << 'Tiros restantes: ' + cant_balas.length.to_s + "\n"
            end

        end

        send_message(chat_id: msg.chat.id,
                     text: text)
    end
end
