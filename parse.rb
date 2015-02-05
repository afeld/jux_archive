require 'json'

quarks_by_id = {}

Dir.glob('downloads/quarks_js*') do |file|
  contents = File.read(file)

  begin
    json = JSON.parse(contents)
  rescue JSON::ParserError
    puts "Skipping #{file}"
  else
    json['quarksData'].each do |quark|
      quarks_by_id[quark['id']] = quark
    end
  end
end

puts quarks_by_id.size
