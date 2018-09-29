require "telegram/bot"

class Dankie
	command ping: "Hace ping"

	def ping(msg)
		return unless msg.is_a? Telegram::Bot::Types::Message and msg.text

		cmd = parse_command(msg.text)
		return unless cmd and cmd[:command] == :ping

		time1 = Time.at(msg.date)
		@api.send_chat_action(chat_id: msg.chat.id, action: "typing")
		enviado = @api.send_message(chat_id: msg.chat.id,
					    text: "pong")
		enviado = Telegram::Bot::Types::Message.new(enviado["result"]) #TODO: validar?

		time2 = Time.new
		@api.edit_message_text(chat_id: msg.chat.id,
				       message_id: enviado.message_id,
				       parse_mode: "markdown",
				       text: "pong\n`#{"%.3f" % (time2.to_r - time1.to_r)}`s")
		@logger.info("pong: #{"%.3f" % (time2.to_r - time1.to_r)}")
	end
end
