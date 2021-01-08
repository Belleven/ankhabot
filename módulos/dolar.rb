require 'nokogiri'

class Dankie
    add_handler Handler::Comando.new(
        :dolar,
        :dolar,
        permitir_params: false
    )
    def dolar(msj)
        @dolar ||= Dolar.new

        texto = @dolar.scrap
        @tg.send_message(chat_id: msj.chat.id, parse_mode: :html,
                         text: texto,
                         descripción: 'Te muestra el precio del dolar',
                         disable_web_page_preview: true,
                         disable_notification: true)
    end

    class Dolar
        def initialize
            @doc = Nokogiri::HTML(URI.open('https://www.dolarhoy.com/'))
            @path_padre = "//div[contains(@class,'pill pill-coti')]".freeze
            @path_dolar = '//h4/a'.freeze
            @path_valores = "//div[contains(@class, 'col-6 text-center')]".freeze
            @path_solidario = "//div[contains(@class, 'col-12 text-center')]".freeze
            @path_actualizacion = "//div[contains(@class,'col-7 text-right')]".freeze
        end

        def scrap
            # Consigo la ruta general donde se encuentran los demas valores
            paginas = @doc.xpath(@path_padre)

            # Agarro todos los dolares posibles
            dolar = conseguir_elementos(paginas, @path_dolar)

            # Cuento su valor
            # Los valores de compra y venta vienen juntos, por lo cual los
            # que separar despues
            valor = conseguir_elementos(paginas, @path_valores)

            # Como soy solidario, pago mas
            valor_solidario = conseguir_elementos(paginas, @path_solidario)

            # Agrupo los valores de a dos, compra y venta juntos
            compra_venta = agrupar_compra_venta(valor, 2)

            # Tambien para el solidario
            compra_venta_total = agrupar_compra_venta(valor_solidario, 1,
                                                      compra_venta: compra_venta)

            # Leo cuando fue la ultima vez que se actualizo el valor
            actualización = paginas.xpath(@path_actualizacion).first.text.strip

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
