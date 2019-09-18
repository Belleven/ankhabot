class Link
    attr_reader :link, :type

    def initialize(link)
        # https://en.wikipedia.org/wiki/Uniform_Resource_Identifier#Generic_syntax
        # La con .gsub sacamos las consultas (vienen después de un '?') y los fragmentos
        # (vienen después de un '#'). Si un link tiene consultas y fragmentos, entra
        # en el primer caso de la expresión regular así que no hay problema.
        @link = link.gsub(/\?.*$|#.*$/, '')
        @type = :image

        # Tomo extensión
        extensión = @link.split('.').last.downcase

        case extensión
        # En cualquiera de estos casos no tengo nada más que hacer
        when 'jpg', 'png', 'jpeg', 'ppm'
            return
        when 'gif'
            @type = :gif
        when 'mp4'
            @type = :video
        when 'svg', 'bmp', 'webp', 'ico'
            @type = :link

        else
            # los links de reddit vienen con &amp:
            if @link.include? 'i.reddituploads.com'
                @link.gsub! 'amp:', ''

            # los gifs de imgur vienen como gifv, es mejor mp4
            elsif /i\.imgur\.com.*gifv/.match?(@link)
                @link.gsub! '.gifv', '.mp4'
                @type = :video

            # acomoda los links de gfycat para que sean gifs
            elsif @link.include? 'gfycat.com'
                @link.gsub!(%r{https?://gfycat.com/(.*)},
                            'https://thumbs.gfycat.com/\\1-size_restricted.gif')
                @type = :gif
            elsif %r{^https?://www\.reddit\.com/r/(\w)*/comments/}.match?(@link)
                @type = :link
            end
        end
    end
end
