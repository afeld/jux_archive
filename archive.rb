# [
#   "urlkey",
#   "timestamp",
#   "original",
#   "mimetype",
#   "statuscode",
#   "digest",
#   "length"
# ]

require 'open-uri'
require 'json'
require 'addressable/uri'
require 'typhoeus'


def friendly_filename(filename)
  filename.
    strip.
    gsub(/^[^\w\d]+|[^\w\d]+$/, '').
    gsub(/[^\w\d]+/, '_')
end

# http://andrey.chernih.me/2014/05/29/downloading-multiple-files-in-ruby-simultaneously/#typhoeus
def download_typhoeus(archives, concurrency=5)
  `rm -rf downloads`
  `mkdir downloads`

  hydra = Typhoeus::Hydra.new(max_concurrency: concurrency)

  archives.each do |archive|
    request = Typhoeus::Request.new(archive.download_url)
    request.on_complete do |response|
      uri = archive.uri
      basename = friendly_filename("#{uri.path} #{uri.query}")
      File.open("downloads/#{basename}.html", "w") do |output|
        output << response.body
      end
      puts "Completed #{archive.url}"
    end
    hydra.queue request
  end

  hydra.run
end


# https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server#readme
data_uri = Addressable::URI.parse('http://web.archive.org/cdx/search/cdx')
data_uri.query_values = {
  url: 'afeld.me',
  matchType: 'host',
  # before shutting down after Nov 2014
  to: '201411',
  output: 'json'
}
puts "Fetching from #{data_uri.to_s}"

archives_str = open(data_uri.to_s).read
archives_json = JSON.parse(archives_str)
headers = archives_json.shift.map(&:to_sym)

Archive = Struct.new(*headers) do
  def uri
    normalized_uri = Addressable::URI.parse(self.original).normalize
    # treat /foo and /foo/ as identical
    if normalized_uri.extname.empty? && !normalized_uri.path.end_with?('/')
      normalized_uri.path += '/'
    end
    normalized_uri
  end

  def url
    self.uri.to_s
  end

  def download_url
    # http://stackoverflow.com/a/26398284/358804
    encoded_url = Addressable::URI.encode_component(self.url, Addressable::URI::CharacterClasses::PATH)
    # http://www.archiveteam.org/index.php?title=Restoring#Unmodified_pages
    "https://web.archive.org/web/#{self.timestamp}id_/#{encoded_url}"
  end

  def time_int
    self.timestamp.to_i
  end
end

archives = archives_json.map { |archive_json| Archive.new(*archive_json) }

archives_by_url = {}
archives.each do |archive|
  if archive.statuscode == '200'
    url = archive.url
    archives_by_url[url] ||= []
    archives_by_url[url] << archive
  end
end

latest_archives = archives_by_url.map do |url, page_archives|
  page_archives.max_by(&:time_int)
end

download_typhoeus(latest_archives)

puts "#{latest_archives.size} pages downloaded."
