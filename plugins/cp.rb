# Extensión de Dankie para generar mensajes cp
class Dankie
    add_handler Handler::Mensaje.new(:añadir_palabras_cp, types: [:text])
    add_handler Handler::Comando.new(:cp, :cp,
                                     description: 'genera una posible '\
                                                  'definición de la sigla cp, '\
                                                  'usando texto del chat')

    def añadir_palabras_cp(msj)
        @palabras_c ||= {}
        @palabras_c[msj.chat.id] ||= []
        @palabras_p ||= {}
        @palabras_p[msj.chat.id] ||= []

        msj.text.split.each do |pal|
            next if pal.size > 30

            @palabras_c[msj.chat.id] << pal if pal.downcase.start_with? 'c'
            @palabras_p[msj.chat.id] << pal if pal.downcase.start_with? 'p'
        end

        [@palabras_c[msj.chat.id], @palabras_p[msj.chat.id]].each do |arr|
            arr.shift while arr.size > 40
        end
    end

    def cp(msj)
        if @palabras_c[msj.chat.id].empty? || @palabras_p[msj.chat.id].empty?
            @tg.send_message(chat_id: msj.chat.id,
                             text: 'Manden más mensajes papus')
        end

        cp = [@palabras_c[msj.chat.id].sample, @palabras_p[msj.chat.id].sample]
        texto = cp.join ' '

        @tg.send_message(chat_id: msj.chat.id, text: texto)
    end
end
