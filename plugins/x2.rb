require "telegram/bot"

class Dankie

	def x2(msg)
		return unless msg.is_a? Telegram::Bot::Types::Message and msg.text
		return unless msg.reply_to_message and (msg.reply_to_message.text or msg.reply_to_message.caption)
		message = msg.text.split(" ").first
		return unless (r = /^[xX](\d*)/) =~ message

		n = message.gsub(r, "\\1").to_i
		text = (msg.reply_to_message.text || msg.reply_to_message.caption) + " "

		if (text.length * n - 1) > 4096
			n = (4096 / text.length) + 1
		end

		if n > 0
			text *= n
			cansado = "... ya fue, me cansé."
			if text.length >= 4096 - cansado.length
				text = text[0..(4096-cansado.length-1)] + cansado
			end
		else
			text = "\"\""
		end

		@api.send_chat_action(chat_id: msg.chat.id, action: "typing")
		@api.send_message(chat_id: msg.chat.id,
					    text: text)
	end
end
