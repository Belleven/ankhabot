require 'telegram/bot'

class Dankie
    add_handler Handler::EventoDeChat.new(:ruleta_supergrupo,
                                          tipos: [:migrate_from_chat_id],
                                          chats_permitidos: %i[supergroup])

    add_handler Handler::Comando.new(:recarga, :recarga,
                                     descripción: 'Recargo la bala y giro la '\
                                                  'ruleta (6 ranuras)')
    add_handler Handler::Comando.new(:dispara, :dispara,
                                     descripción: 'Disparo la próxima bala')
    @@juegos = {}

    def recarga(msj)
        @@juegos[msj.chat.id] ||= [0, []]
        cant_balas, balas_arr = @@juegos[msj.chat.id]

        if cant_balas < 6
            cant_balas += 1
        else
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Ya está lleno el tambor #{TROESMAS.sample}")
            return
        end

        balas_arr = Array.new(cant_balas, true)
        (6 - cant_balas).times { balas_arr.push(false) }
        balas_arr.shuffle!
        @@juegos[msj.chat.id] = [cant_balas, balas_arr]

        # Armo texto para indicar cantidad de balas cargadas,
        # separo casos singular y plural
        balas_cargadas = cant_balas == 1 ? 'bala cargada' : 'balas cargadas'
        texto = "Recargado y girado. Hay #{cant_balas} #{balas_cargadas} "\
                'de 6 en la bersa.'

        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end

    def dispara(msj)
        if @@juegos[msj.chat.id].nil?
            texto = "Si no recargas no te puedo Nismanear #{TROESMAS.sample}."
        else
            juego_actual = @@juegos[msj.chat.id]
            val = juego_actual[1].shift
            if val
                juego_actual[0] -= 1
                texto = "Te Nismaneaste #{TROESMAS.sample}.\n"
            else
                texto = "Sobreviviste #{TROESMAS.sample}.\n"
            end

            if juego_actual.first.zero?
                texto << 'Se acabaron las balas. Vuelvan a recargar.'
                @@juegos.delete(msj.chat.id)
            else
                texto << "Balas restantes: #{juego_actual.first}\n"\
                         "Tiros restantes: #{juego_actual[1].length}"
            end

        end

        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end

    def ruleta_supergrupo(msj)
        return if @@juegos[msj.migrate_from_chat_id].nil?

        @@juegos[msj.chat.id] = @@juegos[msj.migrate_from_chat_id]
        @@juegos.delete(msj.migrate_from_chat_id)
    end
end
