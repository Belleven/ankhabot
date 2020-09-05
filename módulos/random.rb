require 'telegram/bot'

$indice = 8

class Dankie
    add_handler Handler::Comando.new(:tirada, :tirada,
                                     descripción: 'Tiro un dado de dragones y mazmorras')

    # Comprueba que sea un texto valido
    def comprobar_dado(texto)
        texto.match(/[1-9]*d(4|6|8|10|12|20)(\+[1-9])?/)
    end

    def enviar_mensaje_error(error_code)
        case error_code
        when 'caras'
            dado_texto = 'Mira kpo/a, vos te pensas que te voy a tirar tantas veces el dado? Hasta 666 te lo hago sin problemas, pero ubicate'
        when 'modificador'
            dado_texto = 'Por que queres un modificador tan alto??? Hasta 999 te acepto pero sino es mucho trabajo'
        end
        dado_texto
    end

    # A partir del texto, consigue la informacion de la cantidad de tiradas que se necesita
    # Solo se permiten hasta 666 tiradas
    def get_cantidad_dados(texto)
        contador = 0
        # Si lo primero que aparece es un d, entonces significa que esta implicito que la cantidad de tiradas es una sola
        if texto[$indice] == 'd'
            cantidad_dados = '1'
        else
            cantidad_dados = ''
            while (texto[$indice] != 'd') && (contador < 3)
                cantidad_dados += texto[$indice]
                contador += 1
                $indice = $indice + 1
            end
        end
        # Si contador es 3, significa que el numero tiene 4 digitos con lo cual se paso del limite
        # o la cantidad es mayor a 666, devuelve -1 indicando que se produzco un error
        cantidad_dados = '-1' if (contador == 3) || (cantidad_dados.to_i > 666)
        cantidad_dados
    end

    # Devuelve la cantidad de caras de un texto
    def get_cantidad_caras(texto)
        $indice = $indice + 1
        cantidad_caras = ''
        while (texto[$indice] != '+') && (texto[$indice] != '.')
            cantidad_caras += texto[$indice]
            $indice = $indice + 1
        end
        cantidad_caras
    end

    def get_modificador(texto)
        $indice = $indice + 1
        contador = 0
        modificador = ''
        while (texto[$indice] != '.') && (contador < 4)
            modificador += texto[$indice]
            contador += 1
            $indice = $indice + 1
        end
        modificador = '-1' if contador == 4
        modificador
    end

    def conseguir_valor_dado(cantidad_caras = 6, cantidad_dados = 1, modificador = '')
        dado = Dado.new(cantidad_caras.to_i)
        dado_texto = ''
        i = 0
        while i < cantidad_dados.to_i
            valor_dado = dado.tirar_dado
            dado_texto << if modificador == ''
                              "#{valor_dado} "
                          else
                              "#{valor_dado}+#{modificador} "
                          end
            i += 1
        end
        dado_texto
    end

    # Funcion que tira varias veces un dado con modificadores
    def tirada(msj)
        texto = "#{msj&.text}."

        if comprobar_dado(texto)
            cantidad_dados = get_cantidad_dados(texto)

            # Si es -1, indica que se quizo tirar mas veces de lo permitido
            if cantidad_dados == '-1'
                error_code = 'caras'
                error_flag = 1
                dado_texto = enviar_mensaje_error(error_code)
            else

                number_string = get_cantidad_caras(texto)
                modificador = ''
                # El texto puede no tener modificadores, por eso hay que comprobarlo
                modificador = get_modificador(texto) if texto[$indice] == '+'

                # Si se produce un modificador mas alto de lo aceptado
                if modificador == '-1'
                    error_code = 'modificador'
                    error_flag = 1
                    dado_texto = enviar_mensaje_error(error_code)

                else
                    dado_completo = dado_completo_string(texto)
                    dado_texto = conseguir_valor_dado(number_string,
                                                      cantidad_dados, modificador)
                    dado_texto = "#{dado_completo}\n#{dado_texto}"

                end
            end
        else
            dado_texto = 'Kpo, no sabes jugar D&D? El comando es /tirada <NdR+M> donde N es el numero de tiradas y R son las caras usadas que solo pueden ser 4, 6, 8, 10, 12, 20. Si solo esta el rango, devuelve una sola tirada. M es un modificador que aumenta el valor de tus tiros, puede no estar'
        end
        $indice = 8

        @tg.send_message(chat_id: msj.chat.id, text: dado_texto)
    end

    def dado_completo_string(texto)
        dado_completo = ''
        $indice = 8
        while texto[$indice] != '.'
            dado_completo += texto[$indice]
            $indice = $indice + 1
        end
        dado_completo
    end
end

class Dado
    def initialize(cantidad_caras)
        @caras = cantidad_caras - 1
    end

    def tirar_dado
        @valor_tirada = Random.rand @caras
        @valor_tirada + 1
    end
end
