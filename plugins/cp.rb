class Dankie
    add_handler CommandHandler.new(:cp, :cp,
                                   'Te explico qué significa cp')
    
    private

    def cp(msg)
        text = "#{PALABRAS_CON_C.sample} #{PALABRAS_CON_P.sample}"
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'markdown', text: text)
    end
end
