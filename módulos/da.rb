require 'nokogiri'
require 'open-uri'
require 'json'
require_relative 'du_ud'
# Ayuditas para el nokogiri
# http://ruby.bastardsbook.com/chapters/html-parsing/
# https://www.jdbean.net/scraping-with-nokogiri/
# TODO:
# 1.[x] Búsquedas personalizadas
# 2.[ ] Arreglar el código por el amor de dios
# 3.[x] Imitar a du_ud
class Dankie
    add_handler Handler::Comando.new(:da, :diccionario_argentino,
                                     permitir_params: true,
                                     descripción: 'Busco una definición en' \
                                    ' el diccionario argentino.')
    def diccionario_argentino(msj, params)
        url = 'https://www.diccionarioargentino.com/'
        búsqueda_aleatoria(url, msj, params) if params.nil?
        búsqueda_con_param_no_vacío(url, msj, params)
    end

    def búsqueda_con_param_no_vacío(url, msj, params)
        # La dirección url 'https://www.diccionarioargentino.com/term/params'
        # nos deja en la página con definiciones de params, lo encodeo
        # para que no explote si le pasan caracteres raros o espacios al bot.
        params = URI.encode_www_form_component(params.downcase)
        @tg.send_message(chat_id: msj.chat.id,
                         text: params)
        # Armo la url como menciono arriba.
        url = "#{url}term/#{params}"
        html = URI.parse(url).open
        documento = Nokogiri::HTML(html)
        # Arreglo para guardar las definiciones y armar la botonera.
        arr_de_defs = []
        documento.css('.panel-body').collect do |iterador_css|
            # Saco los botones de 'Bueno' y 'Malo'
            iterador_css.css('button')&.remove
            # Saco quién mandó la definición, porque soy un forro.
            iterador_css.css('small')&.remove
            # Me quedo con la definición, el texto del div, y le agrego
            # la url al final.
            arr_de_defs.append(iterador_css.text.to_s + \
                               " \n  #{url}")
        end
        if arr_de_defs.empty?
            @tg.send_message(chat_id: msj.chat.id, text: 'La verdad que' \
            " no encontré nada, #{TROESMAS.sample}")
        else
            mandar_botonera(msj, arr_de_defs)
        end
    end

    def búsqueda_aleatoria(url, msj, _params)
        # La página nos proporciona un término al azar de entrada,
        # Nokogiri me deja agarrar el primer elemento de cierta clase de
        # CSS.
        html = URI.parse(url).open
        documento = Nokogiri::HTML(html)
        primer_parrafo = documento.at_css('p').text.strip
        primer_titulo = documento.at_css('strong').text.strip
        # Los del diccionario joden con que linkeemos su página.
        url = "#{url.strip}term/#{primer_titulo}"
        texto = "#{primer_titulo} \n #{primer_parrafo} \n #{url}"
        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html, text: texto)
    end
end
