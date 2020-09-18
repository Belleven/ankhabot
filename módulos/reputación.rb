class Dankie
    add_handler Handler::Mensaje.new(:cambiar_rep, tipos: [:text])

    # TODO: - enviar una lista de reputación
    #       - que se configuren los disparadores (implementar listas en config?)
    #       - que se configure un antiflood (reciclar el contador de promedios
    #         de pole o poner un cooldown)(configurable también)

    def cambiar_rep(msj)
        # Δrep: 1 si rango = 0
        #       1 + (rep1 - rep2) / rango sí rep1 =/= rep2
        # donde rango = rep_max - rep_min en todo el grupo,
        #       rep1 es el que cambia y
        #       rep2 es el que va a ser cambiado

        return unless msj.reply_to_message
        return if msj.from.id == msj.reply_to_message.from.id
        return unless (cambio = validar_disparadores_rep msj)

        # Veo si ya se tomaron reps en el grupo y busco el rango entre
        # la rep más baja y la más alta
        rango = calcular_rango(msj)
        # El mínimo incremento es 0,001
        delta_rep = [calcular_delta_rep(rango, msj), 0.001].max

        @redis.zincrby(
            "rep:#{msj.chat.id}",
            cambio * delta_rep,
            msj.reply_to_message.from.id
        )

        @tg.send_message(
            chat_id: msj.chat.id,
            parse_mode: :html,
            text: crear_texto_msj(msj, cambio, delta_rep),
            disable_web_page_preview: true
        )
    end

    private

    def validar_disparadores_rep(msj)
        # meterle que los grupos configuren sus propios disparadores
        return 1 if %(+ mas más 👍).include? msj.text.downcase
        return -1 if %(- menos 👎).include? msj.text.downcase

        nil
    end

    def calcular_rango(msj)
        case @redis.zcard("rep:#{msj.chat.id}")
        when 0
            0
        when 1
            @redis.zrevrange("rep:#{msj.chat.id}", 0, 1, with_scores: true)
                  .first.last
        else
            arr = @redis.zrevrange("rep:#{msj.chat.id}", 0, -1,
                                   with_scores: true)
            arr.map!(&:last)
            arr.max - arr.min
        end
    end

    def calcular_delta_rep(rango, msj)
        if rango.zero?
            1
        else
            rep1 = @redis.zscore("rep:#{msj.chat.id}", msj.from.id) || 0
            rep2 = @redis.zscore("rep:#{msj.chat.id}",
                                 msj.reply_to_message.from.id) || 0
            1 + (rep1 - rep2) / rango
        end
    end

    def crear_texto_msj(msj, cambio, delta_rep)
        rep1 = format(
            '<b>(%<rep>.3f)</b> ',
            rep: @redis.zscore("rep:#{msj.chat.id}", msj.from.id) || 0
        )

        rep2 = format(
            '<b>(%<rep>.3f)</b>',
            rep: @redis.zscore("rep:#{msj.chat.id}", msj.reply_to_message.from.id) || 0
        )

        cambio = format(
            '<i>(%<signo>s%<rep>.3f)</i>.',
            signo: (cambio.positive? ? '+' : '-'),
            rep: delta_rep
        )

        usuario1 = obtener_enlace_usuario msj.from.id, msj.chat.id
        usuario2 = obtener_enlace_usuario(msj.reply_to_message.from.id, msj.chat.id)
        cambiado = cambio.positive? ? 'incrementado' : 'reducido'

        "El usuario #{usuario1} #{rep1} ha #{cambiado} la "\
        "reputación de #{usuario2} #{rep2} #{cambio}"
    end
end
