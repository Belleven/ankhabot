class Dankie
    add_handler Handler::Comando.new(:debug, :debug)

    def debug(msj)
        return unless validar_desarrollador(msj.from.id, msj.chat.id, msj.message_id)

        texto = "{\n"
        acomodar_texto_iterable!(msj.datos_crudos, texto, 1)
        texto << '}'

        @tg.send_message(
            chat_id: msj.chat.id,
            text: texto,
            disable_web_page_preview: true,
            disable_notification: true
        )
    end

    private

    def acomodar_texto_iterable!(iterable, texto, profundidad)
        tabs = ' ' * 4 * profundidad

        case iterable
        when Hash
            iterar_texto_debug_dicc(iterable, texto, profundidad, tabs)
        when Array
            iterar_texto_debug_arreglo(iterable, texto, profundidad, tabs)
        end
    end

    def iterar_texto_debug_dicc(iterable, texto, profundidad, tabs)
        return if iterable_vacío iterable, texto, '{}'

        iterable.each_with_index do |(clave, valor), índice|
            texto << "#{tabs}\"#{clave}\": "

            case valor
            when Hash
                texto << "{\n"
                acomodar_texto_iterable! valor, texto, profundidad + 1
                texto << "#{tabs}}"
            when Array
                texto << "[\n"
                acomodar_texto_iterable! valor, texto, profundidad + 1
                texto << "#{tabs}]"
            else
                texto << "\"#{valor}\""
            end

            agrear_separador texto, índice, iterable.size
        end
    end

    def iterar_texto_debug_arreglo(iterable, texto, profundidad, tabs)
        return if iterable_vacío iterable, texto, '[]'

        iterable.each_with_index do |elemento, índice|
            case elemento
            when Hash
                texto << "#{tabs}{\n"
                acomodar_texto_iterable! elemento, texto, profundidad + 1
                texto << "#{tabs}}"
            when Array
                texto << "#{tabs}[\n"
                acomodar_texto_iterable! elemento, texto, profundidad + 1
                texto << "#{tabs}]"
            else
                texto << "#{tabs}\"#{elemento}\""
            end

            agrear_separador texto, índice, iterable.size
        end
    end

    def iterable_vacío(iterable, texto, vacío)
        texto << vacío if (es_vacío = iterable.empty?)
        es_vacío
    end

    def agrear_separador(texto, índice, tamaño)
        texto << ',' if índice != tamaño - 1
        texto << "\n"
    end
end
