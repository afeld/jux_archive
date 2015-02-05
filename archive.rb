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


# http://andrey.chernih.me/2014/05/29/downloading-multiple-files-in-ruby-simultaneously/#typhoeus
def download_typhoeus(archives, concurrency=5)
  `mkdir -p downloads`

  hydra = Typhoeus::Hydra.new(max_concurrency: concurrency)

  archives.each do |archive|
    request = Typhoeus::Request.new(archive.url)
    request.on_complete do |response|
      uri = archive.uri
      basename = "#{uri.path} #{uri.query}".strip.gsub(/[^\w\d]+/, '_')
      File.open("downloads/#{basename}.html", "w") do |output|
        output << response.body
      end
    end
    hydra.queue request
  end

  hydra.run
end


# https://github.com/internetarchive/wayback/tree/master/wayback-cdx-server#readme
HOST = 'afeld.me'
archives_str = open("http://web.archive.org/cdx/search/cdx?url=#{HOST}&matchType=host&output=json").read
archives_json = JSON.parse(archives_str)
headers = archives_json.shift.map(&:to_sym)

Archive = Struct.new(*headers) do
  def uri
    Addressable::URI.parse(self.original).normalize
  end

  def url
    self.uri.normalize.to_s
  end

  def download_url
    # http://stackoverflow.com/a/26398284/358804
    encoded_url = Addressable::URI.encode_component(self.url, Addressable::URI::CharacterClasses::PATH)
    "https://web.archive.org/web/#{self.timestamp}/#{encoded_url}"
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
