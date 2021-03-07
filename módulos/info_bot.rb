class Dankie
    add_handler Handler::Comando.new(:about, :info_bot)

    def info_bot(_msg)
        # texto = 'Bot'
    end
end
