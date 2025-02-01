#!/usr/bin/env ruby

require_relative 'immich-client/lib'
require_relative '../utils'
require 'pp'

if ARGV.size < 1
  STDERR.puts("Usage:\n  #{__FILE__} album_id")
  exit 1
end

SCRIPT_DIR = File.dirname(__FILE__)
load_dotenv(File.join(SCRIPT_DIR, '.env'))
EXTERNAL_LIBRARY_CONTAINER_PATH = ENV['EXTERNAL_LIBRARY_CONTAINER_PATH']
immich_album_id = ARGV[0]

immich_me = immich_api('/user/me')

immich_album = immich_api("/album/#{immich_album_id}")
unless immich_album
  STDERR.puts("album not found")
  exit 1
end

immich_album_name = immich_album['albumName']
immich_album_assets = immich_album["assets"]

deleting_asset_ids = immich_album_assets.filter do |asset|
  asset["ownerId"] == immich_me["id"] and not asset["originalPath"].start_with?(EXTERNAL_LIBRARY_CONTAINER_PATH)
end.map do |asset|
  asset["id"]
end

print("DELETE your #{deleting_asset_ids.size} assets from '#{immich_album_name}'. Continue? [Y/N] ")
if STDIN.gets.strip == 'Y'
  immich_api('/asset',
    method: Net::HTTP::Delete,
    body: {
      force: true, # skip trash
      ids: deleting_asset_ids
    }
  )
  puts("Done")
else
  puts("Cancelled")
end
