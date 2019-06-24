class Dankie
    add_handler MessageHandler.new(:add_cp_words, types: [:text])
    add_handler CommandHandler.new(:cp, :cp,
                                   description: 'genera una posible '\
                                                'definición de la sigla cp, '\
                                                'usando texto del chat')

    def add_cp_words(msg)
        @c_words ||= {}
        @c_words[msg.chat.id] ||= []
        @p_words ||= {}
        @p_words[msg.chat.id] ||= []

        msg.text.split.each do |word|
            @c_words[msg.chat.id] << word if word.downcase.start_with? 'c'
            @p_words[msg.chat.id] << word if word.downcase.start_with? 'p'
        end

        [@c_words[msg.chat.id], @p_words[msg.chat.id]].each do |arr|
            arr.shift while arr.size > 40
        end
    end

    def cp(msg)
        text = [@c_words[msg.chat.id].sample, @p_words[msg.chat.id].sample].join ' '
        @tg.send_message(chat_id: msg.chat.id, parse_mode: 'html', text: html_parser(text))
    end
end
