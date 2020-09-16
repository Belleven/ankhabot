# Dankie Bot


## Installation


    $ git clone git@gitlab.com:lukeovalle/dankiebot.git
    $ cd dankiebot

if you do not have ruby in your machine i don't know dude just google how to install it
ruby 2.6 at least is needed (check with ruby -v in console)
if you have a lower version update it, you can use rvm (to install rvm: https://rvm.io/rvm/install)
	
	$ rvm install 2.6 

or install a higher version like 2.7

if you don't have bundle installed in your master race: 
	
	$ gem install bundler

if this warning shows "WARNING: You don't have /home/USER/.gem/ruby/2.7.0/bin in your PATH, gem executables will not run. (with USER being your user dou, and not necesary be 2.7.0)


And then execute:

    $ bundle install


Redis server installation (for debian, if you use another magic distro you would know wich package manager you have to use):

	$  sudo apt-get install redis


Change the default por to 42069:
First open /etc/redis.conf with your favourite text editor, here I will user nano but you can use whathever shit you want
On Ubuntu:

	$ sudo nano /etc/redis/redis.conf

On other distributions:

	$ sudo nano /etc/redis.conf

Go to port line:
\# Accept connections on the specified port, default is 6379 (IANA #815344).
\# If port 0 is specified Redis will not listen on a TCP socket.
port 6379

and change it to:
port 42069

save and close file.
If you want another port then you have to change config.yml

Then you have to restart redis (the redis.config explains how to do it)


Start redis

	$ systemctl start redis.server


And enable if you are a big pajero like me and don't want to start the server every time you turn on the bot (instead the server will start with the pc)

	$ systemctl enable redis.server


## Config

Copy config-sample.yml to config.yml 
1) Put your Telegram bot API token in 'tg_token'
2) Put your redis' host in 'redis_host' (asumes localhost by default)
3) If you set a password put it in 'redis_pass', else, comment that line
4) Set your timezone in 'timezone', default is Buenos Aires
5) Get a customesearch api (https://developers.google.com/custom-search/v1/overview?authuser=3#api_key) and put it in 'google_image_key'
6) Get a programmable search engine (https://developers.google.com/custom-search/v1/using_rest)
7) A country code (https://developers.google.com/custom-search/docs/xml_results_appendices#countryCodes) in 'google_image_gl'
8) Get a last.fm api (follow instructions https://www.last.fm/api/) and put it in 'last_fm_api'
9) Set a chat to see the logs of the bot (you can use a channel setting the bot as an administrator, or your private chat for example). Put the chat's id in 'canal_logging' as a string. Plz use a valid id, not a bot id or id of a chat that the bot has not acces to it.


## Usage

The bot runs with the following command

    $ ruby bot.rb


## Contributing

Bug reports and pull requests are welcome on GitLab at https://gitlab.com/lukeovalle/dankiebot.


## License

see LICENSE dou
