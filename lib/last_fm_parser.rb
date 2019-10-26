require 'net/http'
require 'json'

module LastFM

    class Api
        PAQUETES = %i[album artist auth chart geo library tag track user].freeze

        def initialize(api)
            @api = api
        end

        def method_missing(paquete, *args, &bloque)
            PAQUETES.include?(paquete) ? Paquete.new(paquete, @api) : super
        end

        def respond_to_missing?(*args)
            PAQUETES.include?(args.first.to_s) || super
        end
    end

    class Paquete
        DIRECCIÓN_BASE = 'https://ws.audioscrobbler.com/2.0/?'.freeze

        MÉTODOS = { album: %w(addTags getInfo getTags getTopTags removeTag search).freeze,
                    artist: %w(addTags getCorrection getInfo getSimilar getTags
                            getTopAlbums getTopTags getTopTracks removeTag search).freeze,
                    auth: %w(getMobileSession getSession getToken).freeze,
                    chart: %w(getTopArtists getTopTags getTopTracks).freeze,
                    geo: %w(getTopArtists getTopTracks).freeze,
                    library: %w(getArtists).freeze,
                    tag: %w(getInfo getSimilar getTopAlbums getTopArtists getTopTags
                            getTopTracks getWeeklyChartList).freeze,
                    track: %w(addTags getCorrection getInfo getSimilar getTags
                              getTopTags love removeTag scrobble search unlove
                              updateNowPlaying).freeze,
                    user: %w(getFriends getInfo getLovedTracks getPersonalTags getRecentTracks
                          getTopAlbums getTopArtists getTopTags getTopTracks
                          getWeeklyAlbumChart getWeeklyArtistChart  getWeeklyChartList
                          getWeeklyTrackChart).freeze
        }.freeze

        def initialize(paquete, api)
            @paquete = paquete
            @api = api
        end

        def llamar_api(método, args)
            solicitud = construir_solicitud(método, args)
            url = DIRECCIÓN_BASE + solicitud
            resp = Net::HTTP.get_response URI.parse(url)
            if resp.code == '200'
                JSON.parse resp.body
            else
                # debería levantar una excepción
                return resp
            end
        end
        
        def construir_solicitud(método, params = nil)
            solicitud = "method=#{método}&format=json"
            solicitud << "&api_key=#{@api}"
            solicitud << '&' << URI.encode_www_form(params) if params
            solicitud
        end

        def camellizar(método)
            método = método.to_s
            palabras = método.split '_'
            palabras.drop(1).each(&:capitalize!)
            palabras.join
        end

        def method_missing(método, *args, &bloque)
            método_api = camellizar(método)

            if MÉTODOS[@paquete].include?(método_api)
                llamar_api("#{@paquete}.#{método_api}", *args)
            else
                super
            end
        end

        def respond_to_missing?(*args)
            método_api = camellizar(args.first)
            MÉTODOS[@paquete].include?(método_api) || super
        end
    end
end
