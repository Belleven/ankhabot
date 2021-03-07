require 'nokogiri'
require 'open-uri'
require 'json'
# Ayuditas para el nokogiri
# http://ruby.bastardsbook.com/chapters/html-parsing/
# https://www.jdbean.net/scraping-with-nokogiri/
# TODO:
# 1.[x] Búsquedas personalizadas
# 2.[ ] Arreglar el código por el amor de dios
# 3.[ ]Imitar a du_ud
class Dankie
    add_handler Handler::Comando.new(:da, :diccionario_argentino,
                                     permitir_params: true)
    def diccionario_argentino(msj, params)
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
            # Los del diccionario joden con que linkeemos su página, no quiero bardos.
            url = "#{url.strip}term/#{primer_titulo}"
            texto = "#{primer_titulo} \n #{primer_parrafo} \n #{url}"
            @tg.send_message(chat_id: msj.chat.id, parse_mode: :html, text: texto)
        else
            # Implementación:
            # Una definición  (existente) consiste de 2 divs dentro de un
            # div clase "panel-heading":
            # 1. div.panel-heading, que contiene el título de lo que buscamos.
            # 2. div.panel-body, que contiene la definición que buscamos, y
            #   un par de regalías más, que podríamos ver si nos sirven más
            #   adelante, pero lo que más nos interesa es la definición :P.
            #   Idea para la implementación:
            #   Iterar sobre los "panel-body" y crear una botonera ;).
            @tg.send_message(chat_id: msj.chat.id,
                             text: params.to_s)
            url = "#{url}term/#{params.downcase}"
            html = URI.parse(url).open
            document = Nokogiri::HTML(html)
            # Texto que devuelvo.
            texto = ''
            document.css('.panel-body').collect do |algo|
                # Saco los botones de 'Bueno' y 'Malo'
                algo.css('button')&.remove
                # Saco quién mandó la definición, porque soy un forro.
                algo.css('small')&.remove
                texto += algo.text
            end
            if texto.empty?
                @tg.send_message(chat_id: msj.chat.id, text: 'La verdad que' \
                "no encontré nada, #{TROESMAS.sample}")
            end
            # target_text = document.css('.panel-body > p').text
            @tg.send_message(chat_id: msj.chat.id, text: texto)
        end
    end
end
