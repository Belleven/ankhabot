require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(
        :tirada,
        :tirada,
        permitir_params: true,
        descripción: 'Un dado de dragones y mazmorras'
    )
    add_handler Handler::Comando.new(
        :roll,
        :tirada,
        permitir_params: true,
        descripción: 'Un dado de dragones y mazmorras'
    )

    # Funcion que tira varias veces un dado con modificadores
    def tirada(msj, params)
        return unless (match = parámetros_tirada_válidos(msj, params))

        # La cantidad de tiradas es N si es que vino en los params, si no es 1
        cant_tiradas =  match[1]
        cant_tiradas =  cant_tiradas.empty? ? 1 : cant_tiradas.to_i

        return if cero_tiradas(msj, cant_tiradas)

        rango = match[2].to_i
        suma = match[3].nil? ? 0 : (match[4] + match[5]).to_i

        return if rango_inválido(msj, rango)
        return if suma_inválida(msj, suma)

        tirar(msj, cant_tiradas, rango, suma)
    end

    private

    def parámetros_tirada_válidos(msj, params)
        if params.nil? || (match = formato_correcto(params)).nil?
            error = 'Se usa como /tirada NdR + M donde N es la cantidad de tiradas, R '\
                    'los valores posibles y M la suma al resultado de cada tirada. N '\
                    'y M son opcionales.'
            @tg.send_message(
                chat_id: msj.chat.id,
                text: error,
                reply_to_message_id: msj.message_id
            )
        end
        match
    end

    # Comprueba que sea un texto valido para el comando
    def formato_correcto(texto)
        /\A([0-9]*)d([0-9]+)(\s*([+\-])\s*([0-9]+))?\z/.match(texto)
    end

    def cero_tiradas(msj, cant_tiradas)
        if cant_tiradas.zero?
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'No puedo tirar 0 veces.',
                reply_to_message_id: msj.message_id
            )
            return true
        end
        false
    end

    def rango_inválido(msj, rango)
        if rango < 2
            @tg.send_message(
                chat_id: msj.chat.id,
                text: "El rango tiene que ser 2 o más, #{TROESMAS.sample}.",
                reply_to_message_id: msj.message_id
            )
            return true
        end
        false
    end

    def suma_inválida(msj, suma)
        if suma.abs > 666
            @tg.send_message(
                chat_id: msj.chat.id,
                text: 'No podés sumar más de 666.',
                reply_to_message_id: msj.message_id
            )
            return true
        end
        false
    end

    # Se fija que no haya una cantidad de tiradas y un rango que en combinación
    # hagan que el resultado sea un mensaje inmenso. Esto es tomando el peor caso
    # posible de las tiradas random, que den los resultados con mayor cantidad de
    # dígitos.
    def resultado_muy_grande(msj, cant_tiradas, rango, suma)
        dígitos_rango = rango.to_s.length
        dígitos_resultados = (dígitos_rango + 1) * cant_tiradas - 1
        suma_final = (cant_tiradas * rango)

        # 42 son los dígitos constantes contando palabras y tags html
        caracteres_msj = cant_tiradas.to_s.length + dígitos_rango +
                         dígitos_resultados + 42

        if suma.zero?
            caracteres_msj += suma_final.to_s.length
        else
            # El 2* es porque la suma aparece 2 veces. El +2 es por los dos paréntesis
            caracteres_msj += (2 * suma.to_s.length) +
                              (suma_final + suma).to_s.length + 2
        end

        if caracteres_msj > 4096
            error = "Números muy grandes, #{TROESMAS.sample}. Probá con menos tiradas "\
                    'o un rango más chico uwu'
            @tg.send_message(
                chat_id: msj.chat.id,
                text: error,
                reply_to_message_id: msj.message_id
            )
            return true
        end
        false
    end

    def tirar(msj, cant_tiradas, rango, suma)
        return if resultado_muy_grande(msj, cant_tiradas, rango, suma)

        texto = "<b>Tirada: #{cant_tiradas}d#{rango}"\
                "#{suma.zero? ? '' : format('%+d', suma)}</b>\n"

        valores = Array.new(cant_tiradas) { rand(1..rango) }

        texto << if suma.zero?
                     "<code>#{valores.join ' '}</code>\n"
                 else
                     "<code>(#{valores.join ' '})#{format('%+d', suma)}</code>\n"
                 end

        texto << "resultado: <code>#{valores.inject(&:+) + suma}</code>"

        @tg.send_message(
            chat_id: msj.chat.id,
            text: texto,
            parse_mode: :html
        )
    end
end
