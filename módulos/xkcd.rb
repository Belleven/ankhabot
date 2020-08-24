require 'xkcd'

class Dankie
    add_handler Handler::Comando.new(:xkcd,
                                     :xkcd,
                                     descripción: 'Devuelvo un cómic aleatorio de xkcd')
    def xkcd(msj)
        # Este método de esta gema devuelve un cómic según el siguiente formato:
        # Título : URL
        # El título termina en 2 puntos, que es seguido por la URL.
        # Me valgo de este formato para hacer un regex que me deje
        # el título y la URL del cómic por separado.
        direccióndelcómic = XKCD.img.to_s
        @tg.send_photo(chat_id: msj.chat.id,
                       # Agarro desde la aparición desde un http
                       photo: direccióndelcómic[/http.*/],
                       # Agarro toda la expresión hasta ':', pero sin incluirlo.
                       caption: direccióndelcómic[/(?:(?!:).)*/],
                       parse_mode: :html)
    end
end
