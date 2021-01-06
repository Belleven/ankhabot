#!/bin/bash
echo "Iniciando a la dankie y al amigo redis uwu..."
sudo systemctl restart redis 
systemctl restart redis
bundle exec ruby bot.rb --sin-updates
