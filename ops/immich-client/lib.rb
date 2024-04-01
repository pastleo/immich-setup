#!/usr/bin/env ruby

require 'net/http'
require 'json'

def immich_api(path, **opts)
  unless ENV['IMMICH_SERVER'].is_a?(String) and ENV['IMMICH_KEY'].is_a?(String)
    raise "env IMMICH_SERVER or IMMICH_KEY not set"
  end

  uri = URI("#{ENV['IMMICH_SERVER']}/api#{path}")
  uri.query = URI.encode_www_form(opts[:search] || {})
  req = (opts[:method] || Net::HTTP::Get).new(uri) # or Net::HTTP::Post, Net::HTTP::Put
  if opts[:body].is_a?(Hash)
    req.body = JSON.generate(opts[:body])
  end
  req['Content-Type'] = 'application/json'
  req['Accept'] = 'application/json'
  req['x-api-key'] = ENV['IMMICH_KEY']

  res = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(req) }

  JSON.parse(res.body) rescue res.body
end

def load_dotenv(file_path)
  if File.exist?(file_path)
    File.foreach(file_path) do |line|
      # Skip comments and empty lines
      next if line.strip.start_with?('#') || line.strip.empty?

      key, value = line.strip.split('=', 2)
      ENV[key] = value
    end
  else
    puts "File not found: #{file_path}"
  end
end
