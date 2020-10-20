require 'telegram/bot'

class Dankie
    add_handler Handler::Comando.new(
        :donaciones,
        :donar,
        descripción: 'Tiene una moneda joven?'
    )
    add_handler Handler::Comando.new(:donar, :donar)

    def donar(msj)
        texto = 'Si querés ayudar a mantenerme podés donar unas '\
                'monedillas así me pagan el servidor y me pueden mejorar '\
                "y agregar más funciones uwu\n\n"\
                "Patreon: https://www.patreon.com/dankiebot\n\n"\
                "Luke:\n"\
                " - Mercado Pago: https://mpago.la/1Dh7edL\n"\
                " - Bitcoin: <b>bc1q3rxz5y2al3f4pygvqn3xuufa9868gangfsdtnc</b>\n"\
                " - ETH / DAI: <b>0xD9d49d85131826275364c7894cC9b945b39670C6</b>\n\n"\
                "Galerazo:\n"\
                " - Bitcoin: <b>34xyEnNNcojgJmdVFdZFTNmPP5ixxygnBB</b>\n"\
                ' - ETH / DAI: <b>0x12e6D08195D9db21E7F1219d2c341C11E0d7bb94</b>'

        @tg.send_message(
            chat_id: msj.chat.id,
            parse_mode: :html,
            text: texto,
            disable_web_page_preview: true
        )
    end
end
