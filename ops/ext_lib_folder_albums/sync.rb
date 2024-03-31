#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'set'
require 'pathname'
require 'fileutils'

SCRIPT_DIR = File.dirname(__FILE__)
DONE_ALBUMS_FILE = File.join(SCRIPT_DIR, 'synced-albums.txt')

def immich_api(path, **opts)
  uri = URI("#{ENV['IMMICH_SERVER']}/api#{path}")
  uri.query = URI.encode_www_form(opts[:search] || {})
  req = (opts[:method] || Net::HTTP::Get).new(uri) # or Net::HTTP::Post, Net::HTTP::Put
  if opts[:body].is_a?(Hash)
    req.body = JSON.generate(opts[:body])
  end
  req['Content-Type'] = 'application/json'
  req['Accept'] = 'application/json'

  unless ENV['IMMICH_KEY'].is_a?(String)
    raise "env IMMICH_KEY not set"
  end
  req['x-api-key'] = ENV['IMMICH_KEY']

  res = Net::HTTP.start(uri.hostname, uri.port) {|http| http.request(req) }

  JSON.parse(res.body)
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

load_dotenv(File.join(SCRIPT_DIR, '../.env'))
EXTERNAL_LIBRARY_HOST_PATH = ENV['EXTERNAL_LIBRARY_HOST_PATH']
EXTERNAL_LIBRARY_CONTAINER_PATH = ENV['EXTERNAL_LIBRARY_CONTAINER_PATH']
EXTERNAL_LIBRARY_ALBUM_LEVEL = ENV['EXTERNAL_LIBRARY_ALBUM_LEVEL']&.to_i || 2

unless EXTERNAL_LIBRARY_HOST_PATH.is_a?(String) && EXTERNAL_LIBRARY_CONTAINER_PATH.is_a?(String)
  puts("env EXTERNAL_LIBRARY_HOST_PATH or EXTERNAL_LIBRARY_CONTAINER_PATH not set.")
  exit 1
end
base_path = Pathname.new(ENV['EXTERNAL_LIBRARY_HOST_PATH'])
unless base_path.directory?
  puts("#{path} is not a directory.")
  exit 1
end

immich_albums = immich_api('/album')

FileUtils.touch(DONE_ALBUMS_FILE)
done_albums = Set.new(File.read(DONE_ALBUMS_FILE).split("\n"))

directories = Dir.glob(base_path.join('**/*/'))
directories_size = directories.size

puts("immich_albums.size: #{immich_albums.size}, external library directories.size: #{directories.size}")
album_already_done = 0
empty_album_count = 0
album_done = 0

directories.each_with_index do |directory_path, index|
  album_name = directory_path.sub(/^#{base_path}\//, '').sub(/\/$/, '')
  if done_albums.include?(album_name)
    album_already_done += 1
    next
  end

  next if album_name.split("/").size < EXTERNAL_LIBRARY_ALBUM_LEVEL

  asset_files = Dir.glob(Pathname.new(directory_path).join('**/*')).filter do |file_path|
    !File.directory?(file_path)
  end.map do |file_path|
    file_path.sub(/^#{directory_path}/, '').sub(/\/$/, '')
  end

  if asset_files.size == 0
    empty_album_count += 1
    next
  end

  puts("[#{index + 1}/#{directories_size}]: #{album_name}")

  begin
    created_immich_album = immich_albums.find do |album|
      album['albumName'] == album_name
    end

    unless created_immich_album
      puts("creating immich album...")
      created_immich_album = immich_api('/album',
        method: Net::HTTP::Post,
        body: {
          "albumName" => album_name
        }
      )
    end

    created_immich_album_id = created_immich_album["id"]
    puts("created_immich_album_id: #{created_immich_album_id}")
    immich_album_assets = immich_api("/album/#{created_immich_album_id}")["assets"]
    immich_album_asset_ids = immich_album_assets.map {|a| a["id"]}

    asset_ids = asset_files.flat_map do |filename|
      container_asset_path = File.join(EXTERNAL_LIBRARY_CONTAINER_PATH, album_name, filename)

      immich_asset = immich_api('/assets',
        search: { 'originalPath' => container_asset_path },
      ).first

      immich_asset_id = immich_asset&.[]("id")
      if immich_asset_id.is_a?(String)
        print(".")

        [immich_asset_id]
      else
        print("?")

        []
      end
    end
    puts("")
    all_assets_found = asset_ids.size == asset_files.size

    asset_ids_to_add = asset_ids.filter {|id| !immich_album_asset_ids.include?(id)}
    asset_ids_to_remove = immich_album_asset_ids.filter do |id|
      !asset_ids.include?(id)
    end.flat_map do |id|
      immich_asset = immich_api("/asset/#{id}")
      if immich_asset["id"] == id and immich_asset["originalPath"].start_with?(EXTERNAL_LIBRARY_CONTAINER_PATH)
        print("x")
        [id]
      else
        print("_")
        []
      end
    end
    puts("")

    puts("all_assets_found: #{all_assets_found}, asset_ids_to_add.size: #{asset_ids_to_add.size}, asset_ids_to_remove.size: #{asset_ids_to_remove.size}")

    adding_assets_to_album = immich_api("/album/#{created_immich_album_id}/assets",
      method: Net::HTTP::Put,
      body: {
        "ids" => asset_ids_to_add
      }
    )
    adding_assets_to_album_all_success = adding_assets_to_album.size == asset_ids_to_add.size && adding_assets_to_album.all? {|o| o["success"]}
    puts("adding_assets_to_album: all success: #{adding_assets_to_album_all_success}")

    removing_assets_to_album = immich_api("/album/#{created_immich_album_id}/assets",
      method: Net::HTTP::Delete,
      body: {
        "ids" => asset_ids_to_remove
      }
    )
    removing_assets_to_album_all_success = removing_assets_to_album.size == asset_ids_to_remove.size && removing_assets_to_album.all? {|o| o["success"]}
    puts("removing_assets_to_album: all success: #{removing_assets_to_album_all_success}")

    if all_assets_found and adding_assets_to_album_all_success and removing_assets_to_album_all_success
      album_done += 1
      File.write(DONE_ALBUMS_FILE, "#{album_name}\n", mode: 'a+')
    end
    puts("")
  rescue RuntimeError => error
    STDERR.puts(error)
  end
end

puts("ok: album_already_done: #{album_already_done}, empty_album_count: #{empty_album_count}, album_done: #{album_done}")
