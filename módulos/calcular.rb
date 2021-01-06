require 'ripper'

class Dankie
    add_handler Handler::Comando.new(
        :calcular,
        :calcular,
        permitir_params: true,
        descripción: 'Calculo la operación que mandes.'
    )

    # Comando calcular.
    def calcular(msj, operación)
        # Captura la operación al responder un mensaje.
        operación = operación || msj.reply_to_message&.text ||
                    msj.reply_to_message&.caption

        operación&.gsub!(/\s+/, '')

        # ¿La operación posee parámetros válidos?
        return if operacón_incorrecta(msj, operación)

        # Reemplazo los caracteres inválidos.
        operación.gsub! '^', '**'
        operación.gsub! 'x', '*'
        operación.gsub! ',', '.'

        # Si es evaluable.
        begin
            # Calculo todo.
            operación_resultado = deducir(operación.to_s).to_s

        # Y si no.
        rescue NoMethodError, ZeroDivisionError => e
            # Log y respuesta ante algún error.
            @logger.error(
                "#{e}\nAl usar el comando /calcular.",
                al_canal: true
            )

            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "Revisá tu operación, #{TROESMAS.sample}."
            )
            return
        end

        # Si el mensaje es demasiado largo.
        if operación_resultado.length > 4096
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'Muy largo che.'
            )
        else
            # Y si no, envío el resultado.
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: operación_resultado
            )
        end
    end

    private

    # Mensaje ante un ingreso incorrecto de parámetros.
    def operacón_incorrecta(msj, operación)
        # Símbolos permitidos.
        permitidos = %r{[^\d|(x+\-*/\^,.%!)]+}

        if operación.nil? || permitidos.match?(operación)
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                parse_mode: :html,
                text: "Pasame una operación legal, #{TROESMAS.sample}.\n"\
                "Es /calcular <i>operación</i>\n"\
                'Sin letras o símbolos raros.'
            )
            return true
        end
        # Dada la situación de resolver un número negativo
        # Lo mando de primera porque no lo detecta como una excepción.
        if /-\d+!/.match?(operación)
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: 'No se puede sacar el factorial '\
                        "de un número negativo, #{TROESMAS.sample}"
            )
            return true
        end
        false
    end

    # Deducir la expresión.
    # Lexiando(lexing) con ripper.
    def deducir(expresión)
        # Sí haya un factorial(!) deja la expresión lista.
        # P.E: 55-(2*4!): f = 4
        regex = /\(([^)]+)\)!|\d+!/
        expresión.match(regex) do |f|
            nuevo = factorial(f)
            expresión = expresión.gsub(regex, nuevo.to_s)
        end
        # Árbol de nodos | root
        #                 |-> child
        tree = Ripper.sexp(expresión)

        # Toma la primera expresión.
        evaluar(tree[-1][0])
    end

    # Evaluar el tipo de expresión.
    def evaluar(nodo)
        tipo, _s = nodo

        case tipo
        when :unary   then evaluar_unario(nodo)
        when :binary  then evaluar_binario(nodo)
        when :paren   then evaluar(nodo[-1][0])
        when :@int    then nodo[1].to_i
        when :@float  then nodo[1].to_f
        end
    end

    # Si el operador es binario.
    # Evaluar con Reverse Polish Notation.
    def evaluar_binario(nodo)
        _s, izquierda, operador, derecha = nodo

        case operador
        when :* then evaluar(izquierda) * evaluar(derecha)
        when :/ then evaluar(izquierda) / evaluar(derecha).to_f
        when :+ then evaluar(izquierda) + evaluar(derecha)
        when :- then evaluar(izquierda) - evaluar(derecha)
        when :** then evaluar(izquierda)**evaluar(derecha)
        when :% then evaluar(izquierda) % evaluar(derecha)
        end
    end

    # Para evitar romper la evaluación sí se antepone '+' o '-'
    # Sí el operador es unario.
    def evaluar_unario(nodo)
        _s, operador, child = nodo

        case operador
        when :+@ then evaluar(child)
        when :-@ then -evaluar(child)
        end
    end

    # Calcula el factorial de un número natural.
    def factorial(número)
        número = número.to_s.gsub(/[()!]/, '')
        (1..deducir(número).to_f).reduce(1, :*)
    end
end
