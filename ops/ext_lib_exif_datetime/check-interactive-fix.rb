#!/usr/bin/env ruby

require_relative '../immich-client/lib'
require_relative '../utils'
require 'set'
require 'pathname'
require 'fileutils'

SCRIPT_DIR = File.dirname(__FILE__)
DONE_ALBUMS_FILE = File.join(SCRIPT_DIR, 'checked-albums.txt')

load_dotenv(File.join(SCRIPT_DIR, '../.env'))
EXTERNAL_LIBRARY_HOST_PATH = ENV['EXTERNAL_LIBRARY_HOST_PATH']
EXTERNAL_LIBRARY_ALBUM_DATE_REGEX = Regexp.new(ENV['EXTERNAL_LIBRARY_ALBUM_DATE_REGEX'])
EXTERNAL_LIBRARY_ALBUM_DATE_STRFTIME = ENV['EXTERNAL_LIBRARY_ALBUM_DATE_STRFTIME']

# https://github.com/immich-app/immich/blob/main/server/src/services/metadata.service.ts#L29
EXIF_DATE_TAGS = [
  "SubSecDateTimeOriginal", "DateTimeOriginal", "SubSecCreateDate", "CreationDate", "CreateDate", "SubSecMediaCreateDate", "MediaCreateDate", "DateTimeCreated",
]
EXPECTED_ASSET_ALBUM_TIMESTAMP_DIFF_FROM = 3 * 30 * 24 * 60 * 60 # 3 months
EXPECTED_ASSET_ALBUM_TIMESTAMP_DIFF_TO = 7 * 24 * 60 * 60 # 7 days
# asset time is expected to be within (album time - expected_asset_album_timestamp_diff_from) ~ (album time + EXPECTED_ASSET_ALBUM_TIMESTAMP_DIFF_TO)

unless EXTERNAL_LIBRARY_HOST_PATH.is_a?(String)
  puts("env EXTERNAL_LIBRARY_HOST_PATH is not set.")
  exit 1
end
base_path = Pathname.new(ENV['EXTERNAL_LIBRARY_HOST_PATH'])
unless base_path.directory?
  puts("#{path} is not a directory.")
  exit 1
end

FileUtils.touch(DONE_ALBUMS_FILE)
done_albums = Set.new(File.read(DONE_ALBUMS_FILE).split("\n"))

directories = Dir.glob(base_path.join('*/*/'))
directories_size = directories.size

puts("external library directories.size: #{directories.size}")
album_already_done = 0
album_done = 0

directories.each_with_index do |directory_path, index|
  album_name = directory_path[(base_path.to_s.size + 1)..-1].sub(/\/$/, '')
  if done_albums.include?(album_name)
    album_already_done += 1
    next
  end

  puts("[#{index + 1}/#{directories_size}]: #{album_name}")
  sleep 3

  album_timedata = EXTERNAL_LIBRARY_ALBUM_DATE_REGEX.match(album_name)
  while not album_timedata
    album_timedata = EXTERNAL_LIBRARY_ALBUM_DATE_REGEX.match(
      readline(
        " !!! date of album '#{album_name}': ",
        Time.now.strftime(EXTERNAL_LIBRARY_ALBUM_DATE_STRFTIME)
      )
    )
  end

  album_time = Time.new(album_timedata[:year].to_i, album_timedata[:month].to_i, album_timedata[:day].to_i)
  album_time_exif_timestr = format_exif_datetime(album_time)

  expected_asset_timestamp_from = album_time.to_i - EXPECTED_ASSET_ALBUM_TIMESTAMP_DIFF_FROM
  expected_asset_timestamp_to = album_time.to_i + EXPECTED_ASSET_ALBUM_TIMESTAMP_DIFF_TO

  puts("album_time: #{format_exif_datetime(album_time)}, expected_asset_timestamp_from: #{format_exif_datetime(Time.at(expected_asset_timestamp_from))}, expected_asset_timestamp_to: #{format_exif_datetime(Time.at(expected_asset_timestamp_to))}")

  asset_pathes = Dir.glob(Pathname.new(directory_path).join('**/*')).filter do |file_path|
    !File.directory?(file_path)
  end

  if asset_pathes.size == 0
    puts("this is an empty album")
    next
  end

  asset_pathes.each do |asset_path|
    existing_asset_exif_time = nil
    EXIF_DATE_TAGS.find do |tag|
      existing_asset_exif_time = parse_exif_datetime(`exiftool -#{tag} -s3 '#{asset_path}'`)
    end

    if existing_asset_exif_time and
        existing_asset_exif_time.to_i > expected_asset_timestamp_from and
        existing_asset_exif_time.to_i < expected_asset_timestamp_to
      print(".")
      next
    end

    puts("")
    writing_asset_exif_time = nil
    while not writing_asset_exif_time
      writing_asset_exif_time = parse_exif_datetime(
        readline(
          " !!! datetime of asset '#{asset_path}': ",
          existing_asset_exif_time ? format_exif_datetime(existing_asset_exif_time) : album_time_exif_timestr
        )
      )
    end

    if writing_asset_exif_time.to_i != existing_asset_exif_time.to_i
      exiftool_cmd_ok = false

      while not exiftool_cmd_ok
        begin
          exiftool_cmd = "exiftool -AllDates='#{format_exif_datetime(writing_asset_exif_time)}' '#{asset_path}'"
          puts("> #{exiftool_cmd}")
          exiftool_cmd_ok = system(exiftool_cmd, exception: true)
        rescue
          if readline(" !!! failed to write '#{asset_path}', rebuild EXIF? ", "Y") == "Y"
            # https://exiftool.org/faq.html#Q20
            exiftool_rebuild_cmd = "exiftool -all= -tagsfromfile @ -all:all -unsafe -icc_profile '#{asset_path}'"
            puts("> #{exiftool_rebuild_cmd}")
            system(exiftool_rebuild_cmd, exception: true)
          end
          puts("retrying...")
        end
      end

      rm_original_cmd = "rm '#{asset_path}_original'"
      puts("> #{rm_original_cmd}")
      system(rm_original_cmd, exception: true)
    end
  end

  album_done += 1
  File.write(DONE_ALBUMS_FILE, "#{album_name}\n", mode: 'a+')
  puts(" ::: ok\n")
end

puts("ok: album_already_done: #{album_already_done}, album_done: #{album_done}")
