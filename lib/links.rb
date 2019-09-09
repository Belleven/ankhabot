class Link
    attr_reader :link, :type

    def initialize(link)
        @link = link
        @type = nil

        extensión = link.split('.').last

        # si tenés http://algo.com/foo.jpg?alguna=boludez, le saca el final
        # TODO: poner mejor esta mugre
        @link.gsub!(/\?.*$/, '') if extensión.include? '?'
        extensión = link.split('.').last

        case extensión
        when 'jpg', 'png', 'bmp', 'jpeg'
            @type = :image
        when 'mp4', 'gif'
            @type = :video
        else
            # los links de reddit vienen con &amp:
            if @link.include? 'i.reddituploads.com'
                @link.gsub! 'amp:', ''
                @type = :image

            # los gifs de imgur vienen como gifv, es mejor mp4
            elsif /i\.imgur\.com.*gifv/.match?(@link)
                @link.gsub! '.gifv', '.mp4'
                @type = :video

            # acomoda los links de gfycat para que sean gifs
            elsif @link.include? 'gfycat.com'
                @link.gsub!(%r{https?://gfycat.com/(.*)}, 'https://thumbs.gfycat.com/\\1-size_restricted.gif')
                @type = :video

            # supongo que otro caso será imagen
            else
                @type = :image
            end
        end
    end
end
