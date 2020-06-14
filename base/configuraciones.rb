# Extensión de Dankie para ver y modificar configuraciones
class Dankie
    add_handler Handler::Comando.new(:configuraciones, :configuraciones,
        descripción: 'Te muestro las configuraciones del grupete')

    #Diccionario de Categorías. Uso: {clave de categoría => descripción}
    CATEGORIAS = {:admite_triggers_globales => "Admite Triggers Globales",
                  :categoría_prueba => "Categoría de Test",
                  :admite_x2 => "Admite usar comando x2"
                 }.freeze()

    def configuraciones(msg)
        Configuración.redis ||= @redis
        respuesta = "Configuraciones del chat:"
        CATEGORIAS.each do |categoria, mensaje|
            valor = parsear_valor_booleano(Configuración.config(msg.chat.id, categoria))
            respuesta << "\n-#{mensaje}: #{valor}"
        end
        @tg.send_message(chat_id: msg.chat.id,
            text: respuesta,
            parse_mode: :html,
            reply_to_message_id: msg&.reply_to_message&.message_id)
    end


    private
    # Parseo las categorías a "Sí" o "No". Por default, "Sí"
    # Caso default ocurre cuando nunca se modificó esa categoría.
    # Si agregamos categorías numéricas, crear otro diccionario de categorías
    # Junto con su parser
    def parsear_valor_booleano(valor)
        return "<b>Si</b>" if valor.nil? || valor.to_i.positive?
        "<b>No</b>"
    end
end
