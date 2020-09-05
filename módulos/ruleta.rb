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

    def recarga(msj)
        @juegos ||= {}
        @juegos[msj.chat.id] ||= Tambor.new

        if @juegos[msj.chat.id].cargadas.positive?
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Ya hay una bala cargada, #{TROESMAS.sample}.")
            return
        end

        @juegos[msj.chat.id].cargar_una
        @juegos[msj.chat.id].girar_tambor

        @tg.send_message(chat_id: msj.chat.id, text: 'Bala cargada, ¿sale chumbazo?')
    end

    def dispara(msj)
        @juegos ||= {}

        unless @juegos[msj.chat.id]
            texto = "Si no recargas no te podés nismanear, #{TROESMAS.sample}."
            @tg.send_message(chat_id: msj.chat.id, text: texto)
            return
        end

        @tg.send_message(chat_id: msj.chat.id, text: '* Apretando gatillo * ...')

        if @juegos[msj.chat.id].gatillar
            emojis = "\u{1F635}\u{1F4A5}\u{1F52B}"
            texto = "Te Nismaneaste, #{TROESMAS.sample}.\nTiren /recarga para seguir jugando."
            @juegos.delete msj.chat.id
        else
            emojis = "\u{1F605}\u{2601}\u{FE0F}\u{1F52B}"
            texto = "zafaste, #{TROESMAS.sample}. Que pruebe otro ahora."
        end

        @tg.send_message(chat_id: msj.chat.id, text: emojis)
        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end

    def ruleta_supergrupo(msj)
        return if @juegos.nil? || @juegos[msj.migrate_from_chat_id].nil?

        @juegos[msj.chat.id] = @juegos[msj.migrate_from_chat_id]
        @juegos.delete(msj.migrate_from_chat_id)
    end
end

class Tambor
    def initialize(tamaño = 6)
        @tamaño = tamaño
        @iterador = 0
        @tambor = Array.new(6) { Recámara.new }
    end

    # Devuelve la cantidad de balas cargadas.
    def cargadas
        @tambor.filter(&:bala?).size
    end

    # Gira el tambor a una posición aleatoria.
    def girar_tambor
        @iterador = Random.rand 6
    end

    # Método que carga una bala en la recámara actual del tambor.
    # Devuelve true si se cargó una bala, false si la recámara ya tenía una bala.
    def cargar_una
        return false if @tambor[@iterador].bala?

        @tambor[@iterador].cargar
        true
    end

    # Método que gatilla la recámara actual del tambor.
    # Devuelve true si había una bala, false si no.
    def gatillar
        disparo = @tambor[@iterador].gatillar
        @iterador = @iterador == @tamaño - 1 ? 0 : @iterador + 1
        disparo
    end
end

class Recámara
    def initialize
        @bala = false
    end

    def cargar
        @bala = true
    end

    # Devuelve true si se disparó una bala, false si no.
    def gatillar
        bala = @bala
        @bala = false
        bala
    end

    def bala?
        @bala
    end
end
