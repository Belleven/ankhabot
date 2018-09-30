require "telegram/bot"

class Dankie
	command rekt: "Informa a un usuario si ha sido destruido"

	def rekt(msg)
		return unless msg.is_a? Telegram::Bot::Types::Message and msg.text

		cmd = parse_command(msg.text)
		return unless cmd and cmd[:command] == :rekt

		text = "☐ Not rekt\n"

		3.times { text << REKT.sample + "\n" }

		@api.send_chat_action(chat_id: msg.chat.id, action: "typing")
		@api.send_message(chat_id: msg.chat.id,
				  reply_to_message_id: msg.reply_to_message ? msg.reply_to_message.message_id : nil,
				  text: text)
	end
end