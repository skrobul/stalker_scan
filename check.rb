#!/usr/bin/env ruby
require 'faraday'
require 'faraday_middleware'
require 'json'

class Checker
  attr_reader :url, :token
  def initialize(url)
    @url = url
  end

  def conn
    Faraday.new do |f|
      # f.response :logger
      f.response :json
      f.options[:open_timeout] = 2
      f.options[:timeout] = 4
    end
  end

  def handshake_headers(mac)
    {
      'User-Agent' => 'Mozilla/5.0 (QtEmbedded; U; Linux; C)',
      'Cookie' => "mac=#{mac}; stb_lang=en; timezone=Europe/Amsterdam;"
    }
  end

  def portal_url
    url.sub('/c/', '/portal.php')
  end

  # type=stb&action=handshake&JsHttpRequest=1-xml
  #
  def params(type, action)
    {
      'type' => type,
      'action' => action,
      'JsHttpRequest' => '1-xml'
    }
  end

  def default_headers
    handshake_headers(@mac)
      .merge({ 'Authorization' => "Bearer  #{@token}"})
  end

  def handshake(mac)
    resp = conn.get(portal_url, params('stb', 'handshake'), handshake_headers(mac))

    if resp.success?
      @token = resp.body['js']['token']
      @mac = mac
      @token
    else
      false
    end
  rescue Faraday::ParsingError
    'auth failed'
  rescue Faraday::ConnectionFailed
    'connection failed'
  end

  def profile
    resp = conn.get(portal_url,
                    params('stb', 'get_profile'),
                    default_headers)
    if resp.success?
      resp.body
    else
      nil
    end
  end

  def categories
    # GET portal.php?type=itv&action=get_genres&JsHttpRequest=1-xml
    resp = conn.get(portal_url,
                    params('itv', 'get_genres'),
                    default_headers)
    if resp.success? && resp.body
      resp.body['js']
    else
      []
    end

  end

end



require 'optparse'

options = { }
parser = OptionParser.new do |parser|
  parser.banner = "Usage: checker.rb [options]"

  parser.on("-i", "--list=FILENAME", "Scan targets listed in file") do |i|
    options[:list] = i
  end

  parser.on("-m", "--mac=MAC", "MAC address to use when checking") do |m|
    options[:mac] = m
  end

  parser.on("-u", "--url=URL", "URL to check") do |u|
    options[:url] = u
  end

  parser.on("-h", "--help", "Prints help") do
    puts parser
    exit
  end
end
parser.parse!

if options[:list]
  File.open(options[:list]).each_line do |line|
    url, mac = line.split
    checker = Checker.new(url)
    result = checker.handshake(mac)
    cat = checker.categories.map { |c| c['title'] }
    if cat.size < 1
      result = 'no channels'
    else
      puts cat
    end
    puts "#{url} - #{mac} - #{result}"
    puts "============================================================================="
  end
elsif options[:url]
  mac_to_check = options[:mac] || '00:1a:79:56:3b:34'
  checker =  Checker.new(options[:url])
  result = checker.handshake(mac_to_check)
  cat = checker.categories.map { |c| c['title'] }
  if cat.size < 1
    result = 'no channels'
  else
    puts cat
  end
  puts "#{options[:url]} - #{mac_to_check} - #{result}"
else
  puts "Specify either a -i or -m and -u"
  puts parser
  exit
end
