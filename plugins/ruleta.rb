require 'telegram/bot'

class Dankie
    command recarga: 'Recarga la bala y gira la ruleta (6 ranuras)'
    command dispara: 'Dispara la próxima bala'
    @@balas = []
    @@cant_balas = 0

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
        @@cant_balas += 1
        @@cant_balas = 6 if @@cant_balas > 6

        @@balas = Array.new(@@cant_balas, true)
        (6 - @@cant_balas).times { @@balas.push(false) }
        @@balas = @@balas.shuffle

        text = "Orden de las balas\n"
        @@balas.each do |i|
            text << (i ? 'bala' : 'vacío') + "\n"
        end

        send_message(chat_id: msg.chat.id,
                     reply_to_message_id: msg&.reply_to_message&.message_id,
                     text: text)
    end

    def dispara(msg)
        if @@balas.empty?
            text = "Si no recargas no te puedo Nismanear papu. \n"
        else
            val = @@balas.shift
            if val
                @@cant_balas -= 1
                text = "Te Nismaneaste papu. \n"
            else
                text = "Sobreviviste \n"
            end

            if @@cant_balas == 0
                text << "Se acabaron las balas. Vuelvan a recargar. \n"
                @@balas = []
            else
                text << 'Balas restantes: ' + @@cant_balas.to_s + "\n"
                text << 'Tiros restantes: ' + @@balas.length.to_s + "\n"
            end

        end

        send_message(chat_id: msg.chat.id,
                     text: text)
    end
end
