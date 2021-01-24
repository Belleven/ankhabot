require 'nokogiri'

class Dankie
    add_handler Handler::Comando.new(
        :dolar,
        :dolar,
        permitir_params: false,
        descripción: 'Te muestra el precio del dolar'
    )
    def dolar(msj)
        @dolar ||= Dolar.new

        texto = @dolar.scrap
        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         text: texto,
                         disable_web_page_preview: true,
                         disable_notification: true)
    end

    class Dolar
        PATH_PADRE = "//div[contains(@class,'pill pill-coti')]".freeze
        PATH_DÓLAR = '//h4/a'.freeze
        PATH_VALORES = "//div[contains(@class, 'col-6 text-center')]".freeze
        PATH_SOLIDARIO = "//div[contains(@class, 'col-12 text-center')]".freeze
        PATH_ACTUALIZACIÓN = "//div[contains(@class,'col-7 text-right')]".freeze

        def initialize
            @doc = Nokogiri::HTML(URI.open('https://www.dolarhoy.com/'))
        end

        def scrap
            # Consigo la ruta general donde se encuentran los demas valores
            paginas = @doc.xpath(PATH_PADRE)

            # Agarro todos los dolares posibles
            dolar = conseguir_elementos(paginas, PATH_DÓLAR)

            # Cuento su valor
            # Los valores de compra y venta vienen juntos, por lo cual los
            # que separar despues
            valor = conseguir_elementos(paginas, PATH_VALORES)

            # Como soy solidario, pago mas
            valor_solidario = conseguir_elementos(paginas, PATH_SOLIDARIO)

            # Agrupo los valores de a dos, compra y venta juntos
            compra_venta = agrupar_compra_venta(valor, 2)

            # Tambien para el solidario
            compra_venta_total = agrupar_compra_venta(valor_solidario, 1,
                                                      compra_venta: compra_venta)

            # Leo cuando fue la ultima vez que se actualizo el valor
            actualización = paginas.xpath(PATH_ACTUALIZACIÓN).first.text.strip

            # Armo el texto con toda la informacion
            texto = mezclar_dolar_valor(dolar, compra_venta_total)
            texto << "\n" << actualización

            texto
        end

        private

        def conseguir_elementos(paginas, path)
            paginas.xpath(path).collect { |node| node.text.strip }
        end

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
