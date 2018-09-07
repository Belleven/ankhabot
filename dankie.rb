class Dankie
	attr_reader :api, :logger, :redis, :reddit, :user

	def initialize(api, logger, redis, reddit)
		@api = api
		@logger = logger
		@redis = redis
		@reddit = reddit
		@user = @api.get_me.dig "result", "username"
	end

	def parse_command(msg)
		msg.downcase!
		return unless msg.start_with? "/"
		arr = msg.split " ", 2
		command = arr[0].gsub("/", "").gsub("@#{@user}", "")
		params = arr[1]

		{ command: command.to_sym, params: params } #TODO: reemplazar esto por un objeto Command????
	end

end
