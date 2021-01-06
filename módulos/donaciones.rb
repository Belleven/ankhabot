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
                ' - Bitcoin (red nativa SegWit-bech32): '\
                "<b>bc1q5qmstwgyx2hv82uvh404m6rzjcc8du7m3k8paa</b>\n"\
                ' - Bitcoin (red SegWit-P2SH): '\
                "<b>34FVYZfsiohAnZvpFGnoRhNFq9F3pLEYfV</b>\n"\
                ' - ETH / DAI / USDT / USDC / REP / HT / UNI / BAT (red ERC20): '\
                "<b>0x03c7fd31d7b3ebcad74755a6d4c722e4b8f39d58</b>\n"\
                " - USDT (red OMNI): <b>14SAXLihSWoLieyA96daQD8K1Ep2CMQTKP</b>\n"\
                ' - BCH (red bitcoin cash node): '\
                '<b>bitcoincash:qrj47mt0qghmcjdeuqas68t9r22yq546ey3whvuqjr</b>'

        @tg.send_message(
            chat_id: msj.chat.id,
            parse_mode: :html,
            text: texto,
            disable_web_page_preview: true
        )
    end
end
