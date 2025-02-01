require "readline"

EXIF_DATETIME_REGEX = /(?<year>\d{4}):(?<month>\d{2}):(?<day>\d{2}) (?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})/
EXIF_DATETIME_STRFTIME = "%Y:%m:%d %H:%M:%S"

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

# https://stackoverflow.com/a/29743124
def readline(prompt, default)
  $stdin.iflush
  Readline.pre_input_hook = -> do
    Readline.insert_text(default)
    # Readline.redisplay

    # Remove the hook right away.
    Readline.pre_input_hook = nil
  end

  Readline.readline(prompt, false)
end

def parse_exif_datetime(string)
  match = EXIF_DATETIME_REGEX.match(string)
  if match
    Time.new(
      match[:year].to_i,
      match[:month].to_i,
      match[:day].to_i,
      match[:hour].to_i,
      match[:minute].to_i,
      match[:second].to_i,
    ) rescue nil
  end
end

def format_exif_datetime(time)
  time.strftime(EXIF_DATETIME_STRFTIME)
end
