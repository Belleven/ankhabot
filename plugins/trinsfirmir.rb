require "telegram/bot"

class Dankie
	command trinsfirmir: "Convierte un texto a isti firmiti"

	def trinsfirmir(msg)
		return unless msg.is_a? Telegram::Bot::Types::Message and msg.text

		cmd = parse_command(msg.text)
		return unless cmd and cmd[:command] == :trinsfirmir

		if not msg.reply_to_message or not (text = msg.reply_to_message.text or msg.reply_to_message.caption)
			text = "Respondele a algo, #{troesma}."
			@api.send_chat_action(chat_id: msg.chat.id, action: "typing")
			@api.send_message(chat_id: msg.chat.id,
					  text: text)
			return
		end

		text.gsub!(/[aeiou]/, "i")
		text.gsub!(/[AEIOU]/, "I")
		text.gsub!(/[áéíóú]/, "í")
		text.gsub!(/[ÁÉÍÓÚ]/, "Í")

		@api.send_chat_action(chat_id: msg.chat.id, action: "typing")
		@api.send_message(chat_id: msg.chat.id,
				  text: text)
		@api.send_sticker(chat_id: msg.chat.id,
				  sticker: "BQADAgADQQEAAksODwABJlVW31Lsf6sC")
	end
end