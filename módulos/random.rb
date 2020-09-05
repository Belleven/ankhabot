require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(:tirada, :tirada, permitir_params: true,
                                                       descripción: 'Un dado de dragones y mazmorras')
    add_handler Handler::Comando.new(:roll, :tirada, permitir_params: true,
                                                     descripción: 'Un dado de dragones y mazmorras')

    # Funcion que tira varias veces un dado con modificadores
    def tirada(msj, params)
        return if parámetros_inválidos(msj, params)

        valores = params.split('-')
        flag = valores.length == 1 ? nil : valores.last.downcase

        return if flag_inválido(msj, flag)

        # La cantidad de tiradas es N si es que vino en los params, si no es 1
        valores = valores.first.split('d')
        cant_tiradas = valores.first.empty? ? 1 : valores.first.to_i

        return if cero_tiradas(msj, cant_tiradas)

        valores = valores.last.split('+')
        rango = valores.first.strip.to_i
        suma = valores.length == 1 ? 0 : valores.last.strip.to_i

        return if rango_inválido(msj, rango)
        return if suma_inválida(msj, suma)
        return if resultado_muy_grande(msj, cant_tiradas, rango, suma, flag)

        tirar(msj, cant_tiradas, rango, suma, flag)
    end

    private

    def parámetros_inválidos(msj, params)
        unless !params.nil? && formato_correcto(params)
            error = 'Se usa como /tirada NdR + M donde N es la cantidad de tiradas, R '\
                    'los valores posibles y M la suma al resultado de cada tirada. N '\
                    'y M son opcionales. Si hay M, podés hacer '\
                    '/tirada NdR + M -acumular si querés que se muestre el resultado '\
                    'de la suma.'
            @tg.send_message(
                chat_id: msj.chat.id,
                text: error,
                reply_to_message_id: msj.message_id
            )
            return true
        end
        false
    end

    # Comprueba que sea un texto valido para el comando
    def formato_correcto(texto)
        /\A[0-9]*d[0-9]+( *\+ *[0-9]+( *-[a-zA-Z]+)?)?\z/.match?(texto)
    end

    def flag_inválido(msj, flag)
        if flag && flag != 'acumular'
            error = 'Parámetro inválido, si querés que se acumulen los resultados '\
                    'acompañá el comando con -acumular'
            @tg.send_message(
                chat_id: msj.chat.id,
                text: error,
                reply_to_message_id: msj.message_id
            )
            return true
        end
        false
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
                text: "El rango tiene que ser 2 o más #{TROESMAS.sample}.",
                reply_to_message_id: msj.message_id
            )
            return true
        end
        false
    end

    def suma_inválida(msj, suma)
        if suma > 666
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
    # hagan que el resultado sea un mensaje inmenso.
    def resultado_muy_grande(msj, cant_tiradas, rango, suma, flag)
        # El tamaño de "<code>" y "</code>"
        tam_html = 13

        # Si tenés el flag activado la parte de "+M" no se muestra, lo mismo si la
        # M es 0
        long_suma = flag || suma.zero? ? 0 : suma.digits.length + 1

        # Si está el flag activado entonces el resultado que se muestra es el de
        # la tirada + la suma, asumiendo que sale el número más grande posible
        # en la tirada (que es el que puede tener más dígitos) se le suma M para
        # ver si se agregan más dígitos o no, si no está activado el flag, no hay que
        # sumar nada (o bueno sumar 0 como hago acá para tener todo en una línea)
        max_digitos_tirada = (rango + (flag ? 0 : suma)).digits.length

        # A max_digitos_tirada se le suma 1 porque despues de poner el resultado
        # de cada tirada hay que poner un espacio (para separarlo del siguiente),
        # salvo en el últmo que no hay que poner espacio y por eso hay un -1 al final
        tamaño = tam_html + cant_tiradas * (max_digitos_tirada + long_suma + 1) - 1

        # 4096 es la longitud máxima de caracteres por mensaje que se pueden mandar
        if tamaño > 4096
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

    def tirar(msj, cant_tiradas, rango, suma, flag)
        # Líneas místicas, en la primera se calcula el resultado que se va a mostrar
        # en el mensaje, se suma 'suma' si el flag está activado.
        # La segunda línea es para ver si al resultado hay que agregarle '+M'
        # Si el flag está activado o si 'suma' == 0 entonces NO hay que mostrarla,
        # en otro caso sí.
        valores = Array.new(cant_tiradas) do
            resultado = rand(1..rango) + (flag ? suma : 0)
            resultado.to_s + (flag || suma.zero? ? '' : "+#{suma}")
        end

        @tg.send_message(
            chat_id: msj.chat.id,
            text: "<code>#{valores.join(' ')}</code>",
            parse_mode: :html
        )
    end
end
