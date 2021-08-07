class Dankie
    add_handler Handler::EventoDeChat.new(
        :cp_supergrupo,
        tipos: [:migrate_from_chat_id],
        chats_permitidos: %i[supergroup]
    )

    add_handler Handler::Mensaje.new(:añadir_palabras_cp, tipos: [:text])

    add_handler Handler::Comando.new(
        :cp,
        :cp,
        descripción: 'Genero una posible definición de la sigla '\
                     'cp usando texto del chat'
    )

    def añadir_palabras_cp(msj)
        CP.redis = @redis

        palabras = msj.text.split.group_by { |pal| pal[0].downcase }

        CP.cargar_c(msj.chat.id, palabras['c']) if palabras['c']
        CP.cargar_p(msj.chat.id, palabras['p']) if palabras['p']
    end

    def cp(msj)
        par_cp = CP.par_cp(msj.chat.id)

        if par_cp.size != 2
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Hacen falta más mensajes')
            return
        end

        texto = par_cp.join ' '

        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end

    def cp_supergrupo(msj)
        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'cp:c:')

        cambiar_claves_supergrupo(msj.migrate_from_chat_id,
                                  msj.chat.id,
                                  'cp:p:')
    end
end

class CP
    class << self
        attr_writer :redis

        def redis
            return @redis if @redis

            Redis.new
        end

        def par_cp(grupo)
            palabras = %w[c p].map do |inicial|
                @redis.lrange("cp:#{inicial}:#{grupo}", 0, -1).sample
            end

            palabras.compact
        end

        def cargar_c(grupo, palabras)
            cargar_palabra(grupo, 'c', palabras)
        end

        def cargar_p(grupo, palabras)
            cargar_palabra(grupo, 'p', palabras)
        end

        private

        def cargar_palabra(grupo, inicial, palabras)
            @redis.lpush("cp:#{inicial}:#{grupo}", palabras)
            @redis.ltrim("cp:#{inicial}:#{grupo}", 0, 49)
        end
    end
end
