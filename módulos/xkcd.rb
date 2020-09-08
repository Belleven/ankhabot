require 'net/http'

class Dankie
    add_handler Handler::Comando.new(:xkcd,
                                     :xkcd,
                                     permitir_params: true,
                                     descripción: 'Devuelvo un cómic aleatorio de '\
                                     'XKCD, si me pasás un id válido de algún cómic'\
                                     ' devuelvo ese cómic en particular.')
    def xkcd(msj, entrada)
        # Compruebo si es una entrada vacía.
        if entrada.nil?
            mandar_comic(msj, numero_comic_random)
            return
        end

        # Compruebo si hay algun caracter que no sea un número.
        return if parámetro_inválido(msj, entrada)

        entrada = entrada.to_i
        return if número_inválido(msj, entrada)

        mandar_comic(msj, entrada)
    end

    private

    def numero_comic_random
        último_comic = último_XKCD['num']
        nro = rand(1..último_comic)
        nro = último_comic if nro == 404
        nro
    end

    def mandar_comic(msj, nro_comic)
        link = "https://xkcd.com/#{nro_comic}"

        respuesta = Net::HTTP.get_response(URI("#{link}/info.0.json"))
        return mandar_error_nro(msj) if respuesta.code == '404'

        comic = JSON.parse(respuesta.body)

        título = "<b>#{html_parser(comic['title'])}</b>"
        descripción = html_parser(comic['alt'])

        texto = "#{título} (#{comic['num']})\n#{descripción}"
        caption = "#{texto} <b>[</b><a href=\"#{link}\">link</a><b>]</b>"

        @logger.info("Mandando xkcd #{link}")
        @tg.send_photo(
            chat_id: msj.chat.id,
            photo: comic['img'],
            caption: caption,
            parse_mode: :html,
            disable_web_page_preview: true
        )
    end

    def parámetro_inválido(msj, entrada)
        if /\D/.match?(entrada)
            @tg.send_message(
                chat_id: msj.chat.id,
                reply_to_message_id: msj.message_id,
                text: "Pasame un id válido, #{TROESMAS.sample}."
            )
            return true
        end
        false
    end

    def número_inválido(msj, entrada)
        # Compruebo que el id de cómic que me dan sea válido.
        if entrada == 404 || entrada.zero?
            mandar_error_nro(msj)
            return true
        end
        false
    end

    def mandar_error_nro(msj)
        @tg.send_message(
            chat_id: msj.chat.id,
            reply_to_message_id: msj.message_id,
            text: "Pasame un id válido, #{TROESMAS.sample}."
        )
    end

    def último_XKCD
        respuesta = Net::HTTP.get_response(URI('https://xkcd.com/info.0.json'))
        JSON.parse(respuesta.body)
    end
end
