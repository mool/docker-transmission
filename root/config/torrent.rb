#!/usr/bin/env ruby

#####################################################################
# Configuration
#####################################################################
download_dir = ENV['TR_TORRENT_DIR']
torrent_name = ENV['TR_TORRENT_NAME']
torrent_id = ENV['TR_TORRENT_ID']
target_path = '/media'
movies_path = "#{target_path}/movies"
series_path = "#{target_path}/tvshows"

telegram_token = ENV['TELEGRAM_TOKEN']
telegram_chat_id = ENV['TELEGRAM_CHAT_ID']
telegram_url = "https://api.telegram.org/bot#{telegram_token}/sendMessage"

transmission_user = ENV['TRANSMISSION_USER']
transmission_password = ENV['TRANSMISSION_PASSWORD']
#####################################################################

require 'to_name'
require 'fileutils'
require 'json'
require 'net/http'
require 'uri'

torrent_path = "#{download_dir}/#{torrent_name}"
info = ToName.to_name torrent_name

if torrent_name =~ /[sS]\d{1,2}[eE]\d{1,2}/
  show_path = "#{series_path}/#{info.name}"
  season_path = "#{show_path}/Temporada #{info.series}"

  [series_path, show_path, season_path].map do |dir|
    Dir.mkdir dir unless File.directory? dir
  end

  if File.directory?(torrent_path)
    Dir.entries(torrent_path).each do |f|
      if f =~ /.*(mkv|mp4)/
        puts "Moving file from #{torrent_path}/#{f} to #{season_path}/#{f}"
        FileUtils.mv "#{torrent_path}/#{f}", "#{season_path}/#{f}"
      end
    end
    FileUtils.rm_rf torrent_path
  else
    puts "Moving file from #{torrent_path} to #{season_path}/#{torrent_name}"
    FileUtils.mv torrent_path, "#{season_path}/#{torrent_name}"
  end

  telegram_text = "TV show *#{info.name}* season #{info.series} episode #{info.episode} was downloaded"
else
  movie_path = "#{movies_path}/#{info.name}"

  Dir.mkdir movie_path unless File.directory? movie_path

  if File.directory?(torrent_path)
    Dir.entries(torrent_path).each do |f|
      if f =~ /.*(mkv|mp4)/
        puts "Moving file from #{torrent_path}/#{f} to #{movie_path}/#{info.name}/#{f}"
        FileUtils.mv "#{torrent_path}/#{f}", "#{movie_path}/#{f}"
      end
    end
    FileUtils.rm_rf torrent_path
  else
    puts "Moving file from #{torrent_path} to #{movie_path}/#{torrent_name}"
    FileUtils.mv torrent_path, "#{movie_path}/#{torrent_name}"
  end

  telegram_text = "Movie *#{info.name}* was downloaded"
end

message = {
  chat_id: telegram_chat_id,
  parse_mode: 'Markdown',
  text: telegram_text
}

uri = URI.parse(telegram_url)
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
request = Net::HTTP::Post.new(uri.request_uri)
request.body = URI.encode_www_form message

# Send the request
response = http.request(request)

puts 'Telegram notification sent: OK' if response.code == '200'
system "/usr/bin/transmission-remote --auth #{transmission_user}:#{transmission_password} -t #{torrent_id} -r"
