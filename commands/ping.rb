class Dankie
	def ping(msg)
		@api.send_chat_action(chat_id: msg.chat.id, action: "typing")
		@api.send_message(chat_id: msg.chat.id,
				  text: "pong")

	end
end
