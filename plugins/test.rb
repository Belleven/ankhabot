require 'telegram/bot'

class Dankie
    command test: 'Para testear papurri'

    def test(msg)
        return unless msg.is_a?(Telegram::Bot::Types::Message)
        
        cmd = parse_command(msg)
        return unless cmd && (cmd[:command] == :test)

        text = ""
        (1..4100).each do        
            text += "A"
        end

        send_message(chat_id: msg.chat.id,
                     parse_mode: 'markdown',
                     text: text)
    end
end