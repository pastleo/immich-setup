#!/usr/bin/env ruby

require 'pathname'
require 'set'

# pacman -S ruby

if ARGV.size < 3
  puts("Usage:")
  puts("  ./import.rb path/to/memories.prepare path/to/admin-library imported-albums.txt | tee imported-albums.log")
  puts("")
  puts("this import assume storage template is hacked to '{{{albumPath}}}/{{filename}}'")
  exit 1
end

memories_root = ARGV[0]
library_root = ARGV[1]
done_albums_file = ARGV[2]

SCRIPT_DIR = File.dirname(__FILE__)

def system!(cmd_line)
  puts("> #{cmd_line}")
  if cmd_line.is_a? String
    system(cmd_line)
  else
    system(*cmd_line)
  end
  raise "exited with #{$?.exitstatus} from: #{cmd_line}" unless $?.success?
end

puts({
  memories_root: memories_root,
  library_root: library_root,
  done_albums_file: done_albums_file,
})
puts("")

system!("touch '#{done_albums_file}'")
done_albums = Set.new(File.read(done_albums_file).split("\n"))

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

  begin
    asset_files = Dir.entries(directory).filter do |file|
      file_path = File.join(directory, file)
      !File.directory?(file_path)
    end

    if asset_files.size > 0
      asset_pathes = asset_files.map do |file|
        File.join(directory, file)
      end

      system!(["#{SCRIPT_DIR}/../immich-client/go-cli.sh", 'upload', '--album', album_name] + asset_pathes)
      puts("uploaded, expecting #{asset_files.size} files, sleep 10s first...")
      sleep(10)

      loop do
        library_album_path = File.join(library_root, album_name)
        puts("checking in #{library_album_path}")
        library_album_files = Dir.entries(library_album_path)
        uploaded_processed = asset_files.filter do |file|
          library_album_files.include?(file)
        end
        if uploaded_processed.size == asset_files.size
          puts("all #{uploaded_processed.size} files present in library album folder, good")
          break
        end

        puts("only #{uploaded_processed.size} files in library album folder, starting storageTemplateMigration and waiting for 10s")
        system!("#{SCRIPT_DIR}/../immich-client/curl.sh /api/jobs/storageTemplateMigration -X PUT --data-raw '{\"command\":\"start\",\"force\":false}'")
        puts("")
        sleep 10
      end
    end

    File.write(done_albums_file, "#{album_name}\n", mode: 'a+')
  rescue RuntimeError => error
    STDERR.puts(error)
  end
end
