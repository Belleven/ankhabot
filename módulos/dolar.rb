require 'nokogiri'

class Dankie
    add_handler Handler::Comando.new(
        :dolar,
        :dolar,
        permitir_params: false
    )
    def dolar(msj)
        dolar = Dolar.new
        texto = dolar.scrap
        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         text: texto,
                         disable_web_page_preview: true,
                         disable_notification: true)
    end

    class Dolar
        def initialize
            @doc = Nokogiri::HTML(URI.open('https://www.dolarhoy.com/'))
            # puts(@doc)
        end

        def scrap
            # Consigo la ruta general donde se encuentran los demas valores
            paginas = @doc.xpath("//div[contains(@class,'container body-content')]/
                div[contains(@class,'container')]/div[contains(@class,'row')]/
                div[contains(@class,'col-md-8')]/div[contains(@class,'row')]/
                div[contains(@class,'col-12 col-lg-6')]
                /div[contains(@class,'pill pill-coti')]")

            # Agarro todos los dolares posibles
            dolar = paginas.xpath('//h4/a').collect { |node| node.text.strip }

            # Cuento su valor
            valor = paginas.xpath("//div[contains(@class,'row')]/
                div[contains(@class, 'col-6 text-center')]").collect do |node|
                node.text.strip
            end

            # Como soy solidario, pago mas
            valor_solidario = paginas.xpath("//div[contains(@class,'row')]/
                div[contains(@class, 'col-12 text-center')]").collect do |node|
                node.text.strip
            end
            # Agrupo los valores de a dos, compra y venta juntos
            compra_venta = agrupar_compra_venta(valor, 2)
            # Tambien para el solidario
            compra_venta_total = agrupar_compra_venta(valor_solidario, 1,
                                                      compra_venta: compra_venta)

            # Leo cuando fue la ultima vez que se actualizo el valor
            actualizacion = paginas.xpath("//div[contains(@class,'foot')]/
                div[contains(@class,'row')]/
                div[contains(@class,'col-7 text-right')]").first.text.strip

            # Armo el texto con toda la informacion
            texto = mezclar_dolar_valor(dolar, compra_venta_total)
            texto << "\n" << actualizacion

            texto
        end

        private

        def agrupar_compra_venta(valores, contador_limite, compra_venta: [])
            texto = ''
            contador = 0
            valores.each do |valor|
                palabra = valor.gsub("\n", '').gsub(' ', '').gsub('$', ' $')
                texto << palabra << "\n"
                contador += 1
                next unless contador == contador_limite

                compra_venta << (texto << "\n")
                texto = ''
                contador = 0
            end
            compra_venta
        end

        def mezclar_dolar_valor(dolares, valores)
            texto = ''
            dolares.zip(valores).each do |dolar, valor|
                texto << '<b><i>' << dolar << '</i></b>' << "\n" << valor
            end
            texto
        end
    end
end
