require 'xkcd'

class Dankie
    add_handler Handler::Comando.new(:xkcd,
                                     :xkcd,
                                     permitir_params: true,
                                     descripción: 'Devuelvo un cómic aleatorio de '\
                                     'XKCD, si me pasás un id válido de algún cómic'\
                                     ' devuelvo ese cómic en particular.')
    def xkcd(msj, entrada)
        # Esta gema devuelve un cómic según el siguiente formato:
        # Título : URL
        # El título termina en 2 puntos, que es seguido por la URL.
        # Me valgo de este formato para hacer un regex que me deje
        # el título y la URL del cómic por separado.

        # Compruebo si es una entrada vacía.
        if entrada.nil? || entrada.strip.empty?
            dirección = html_parser(XKCD.img.to_s)
            @tg.send_photo(chat_id: msj.chat.id,
                           photo: dirección[/http.*/],
                           caption: dirección[/(?:(?!:).)*/],
                           parse_mode: :html)
        # Compruebo si hay algun caracter que no sea un número.
        elsif entrada.match?(/\D/)
            @tg.send_message(chat_id: msj.chat.id,
                             reply_to_message_id: msj.message_id,
                             text: "Pasame un id válido, #{TROESMAS.sample}.")
        else
            último_XKCD = JSON.parse(open('https://xkcd.com/info.0.json').read)['num']
            entrada = entrada.to_i
            # Compruebo que el id de cómic que me dan sea válido.
            if entrada == 404 || entrada > último_XKCD || entrada.zero?
                @tg.send_message(chat_id: msj.chat.id,
                                 reply_to_message_id: msj.message_id,
                                 text: "Pasame un id válido, #{TROESMAS.sample}.")
            else
                dirección = html_parser(XKCD.get_comic(entrada))
                @tg.send_photo(chat_id: msj.chat.id,
                               photo: dirección[/http.*/],
                               caption: dirección[/(?:(?!:).)*/],
                               parse_mode: :html)
            end

        end
    end
end
