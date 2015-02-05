require 'date'
require 'json'

quarks = []

Dir.glob('downloads/quarks_js*') do |file|
  contents = File.read(file)

  begin
    json = JSON.parse(contents)
  rescue JSON::ParserError
    puts "Skipping #{file}"
  else
    json['quarksData'].each do |quark|
      quarks << quark
    end
  end
end

quarks_by_id = quarks.group_by{|q| q['id'] }
# there are duplicates of each quark, so grab the most recently updated one
latest_quarks = quarks_by_id.map do |qid, quarks|
  quarks.max_by{|q| DateTime.parse(q['updated_at']) }
end

puts latest_quarks.size
