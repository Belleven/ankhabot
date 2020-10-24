class Dankie
    add_handler Handler::Comando.new(
        :anuncios,
        :anuncios,
        permitir_params: true,
        descripción: 'Anuncios para hacer (solo devs)'
    )

    def anuncios(msj, params)
        return unless !params.nil? && DEVS.member?(msj.from.id)

        grupo_activos      = @redis.smembers('chat:group:activos')
        supergrupo_activos = @redis.smembers('chat:supergroup:activos')
        grupos = grupo_activos | supergrupo_activos
        grupos.each do |grupete|
            @tg.send_message(chat_id: grupete.to_i,
                             text: params)
        rescue Telegram::Bot::Exceptions::ResponseError => e
            case e.to_s
            when /bot is not a member of the (super)?group chat/
                remover_grupete(grupete)
            end
        end
    end

    def remover_grupete(chat_id)
        if @redis.smembers('chat:group:activos').member?(chat_id)
            @redis.srem('chat:group:activos', chat_id)
            @redis.sadd('chat:group:eliminados', chat_id)
        else
            @redis.srem('chat:supergroup:activos', chat_id)
            @redis.sadd('chat:supergroup:eliminados', chat_id)
        end
    end
end
