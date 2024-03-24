#!/usr/bin/env ruby

require 'pathname'
require 'set'

# pacman -S ruby perl-image-exiftool

if ARGV.size < 3
  puts("Usage:")
  puts("  ./sort.rb path/to/memories.prepare path/to/memories.bak sorted-albums.txt")
  exit 1
end

memories_root = ARGV[0]
bak_root = ARGV[1]
done_albums_file = ARGV[2]

# immich server-info from @immich/cli
supported_image_types = "3fr,ari,arw,avif,bmp,cap,cin,cr2,cr3,crw,dcr,dng,erf,fff,gif,heic,heif,hif,iiq,insp,jpe,jpeg,jpg,jxl,k25,kdc,mrw,nef,orf,ori,pef,png,psd,raf,raw,rw2,rwl,sr2,srf,srw,tif,tiff,webp,x3f"
supported_video_types = "3gp,avi,flv,insv,m2ts,m4v,mkv,mov,mp4,mpg,mts,webm,wmv"

supported_file_types = supported_image_types.split(",") + supported_video_types.split(",")

`touch "#{done_albums_file}"`
done_albums = Set.new(File.read(done_albums_file).split("\n"))

puts({
  memories_root: memories_root,
  bak_root: bak_root,
  done_albums_file: done_albums_file,
})
puts("")

base_path = Pathname.new(memories_root)
unless base_path.directory?
  puts("#{path} is not a directory.")
  exit 1
end

directories = Dir.glob(base_path.join('**/*/'))
directories_size = directories.size
directories.each_with_index do |directory, index|
  album_name = directory.sub(/^#{base_path}\//, '').sub(/\/$/, '')
  next if done_albums.include?(album_name)

  puts("[#{index + 1}/#{directories_size}]: #{album_name}")
  album_year = album_name.match(/^\d{4}/)[0] rescue "2000"
  album_bak_path = File.join(bak_root, album_name)

  fallback_exif_date = "#{album_year}:01:01 00:00:00"
  wrong_ext_log = []
  files_unsupported = []
  files_without_exif_date = []
  Dir.entries(directory).each do |file|
    file_path = File.join(directory, file)

    next if File.directory?(file_path)
    raise "file_path: #{file_path} contains special character!" if file_path.match(/'|"/)

    exif_validations = `exiftool -validate -warning -error -a "#{file_path}"`
    wrong_file_ext_warning = exif_validations.match(/File has wrong extension \(should be (\w+), not (\w+)\)/)
    if wrong_file_ext_warning
      `mkdir -p "#{album_bak_path}"`
      backup_wrong_ext_cmd = "cp -v '#{file_path}' '#{album_bak_path}'"
      wrong_ext_log.push("wrong ext: #{backup_wrong_ext_cmd}")
      wrong_ext_log.push(`#{backup_wrong_ext_cmd}`)
      correct_file = "#{File.basename(file,'.*')}.#{wrong_file_ext_warning[1].downcase}"
      correct_file_path = File.join(directory, correct_file)
      correct_ext_cmd = "mv -v '#{file_path}' '#{correct_file_path}'"
      wrong_ext_log.push("wrong ext: #{correct_ext_cmd}")
      wrong_ext_log.push(`#{correct_ext_cmd}`)

      file = correct_file
      file_path = correct_file_path

      print("_")
    end

    if not supported_file_types.include?(File.extname(file).sub(".", "").downcase)
      files_unsupported.push(file)
      print("x")
      next
    end

    exif_all_dates = `exiftool -AllDates "#{file_path}"`
    if exif_all_dates.size > 0
      fallback_exif_date = exif_all_dates.split("\n")[-1].match(/: *(.+)/)[1]
      print(".")
    else
      files_without_exif_date.push(file)
      print("?")
    end
  end
  puts("")

  puts(wrong_ext_log)

  if files_unsupported.size > 0
    `mkdir -p "#{album_bak_path}"`
    file_pathes_to_move = files_unsupported.map do |file|
      "'#{File.join(directory, file)}'"
    end.join(" ")
    move_unsupported_cmd = "mv -v #{file_pathes_to_move} '#{album_bak_path}'"
    puts("move unsupported files: #{move_unsupported_cmd}")
    puts(`#{move_unsupported_cmd}`)
  end

  if files_without_exif_date.size > 0
    file_pathes_to_set_date = files_without_exif_date.map do |file|
      "'#{File.join(directory, file)}'"
    end.join(" ")
    set_exif_date_cmd = "exiftool -AllDates='#{fallback_exif_date}' #{file_pathes_to_set_date}"
    puts("> #{set_exif_date_cmd}")
    puts(`#{set_exif_date_cmd}`)

    `mkdir -p "#{album_bak_path}"`
    files_without_exif_date.each do |file|
      ori_file_path = File.join(directory, "#{file}_original")
      bak_file_path = File.join(album_bak_path, file)
      puts(`mv -v '#{ori_file_path}' '#{bak_file_path}'`)
    end
  end

  File.write(done_albums_file, "#{album_name}\n", mode: 'a+')
end
