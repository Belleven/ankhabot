require 'nokogiri'
require 'open-uri'
require 'json'

# 1. Búsquedas personalizadas
# 2. Arreglar el código por el amor de dios
# 3. Imitar a du_ud
class Dankie
    add_handler Handler::Comando.new(:da, :diccionario_argentino,
                                     permitir_params: true)
    def diccionario_argentino(msj, params)
        # Nuestro target
        url = 'https://www.diccionarioargentino.com/'
        html = URI.parse(url).open
        document = Nokogiri::HTML(html)
        if params.nil?
            # La página nos proporciona un término al azar de entrada,
            # Nokogiri me deja agarrar el primer elemento de cierta clase de
            # CSS.
            # parrafos = document.css('p')
            primer_parrafo = document.at_css('p').text.strip
            primer_titulo = document.at_css('strong').text.strip
            # Los del diccionario joden con que linkeemos su página; no quiero bardos.
            url = "#{url.strip}term/#{primer_titulo}"
            texto = "#{primer_titulo} \n #{primer_parrafo} \n #{url}"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html, text: texto)
        else
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                             text: "Aún no implementamos esto, #{TROESMAS.sample}")
        end
    end
end
