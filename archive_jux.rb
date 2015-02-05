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
def download_typhoeus(urls, concurrency=5)
  hydra = Typhoeus::Hydra.new(max_concurrency: concurrency)

  urls.each do |url|
    request = Typhoeus::Request.new url
    request.on_complete do |response|
      write_file url, response.body
    end
    hydra.queue request
  end

  hydra.run
end


HOST = 'afeld.me'
# collapse=urlkey
archives_str = open("http://web.archive.org/cdx/search/cdx?url=#{HOST}&matchType=host&output=json").read
archives_json = JSON.parse(archives_str)

headers = archives_json.shift.map(&:to_sym)
Archive = Struct.new(*headers) do
  def url
    uri = Addressable::URI.parse(self.original)
    uri.normalize.to_s
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

download_urls = archives_by_url.map do |url, page_archives|
  archive = page_archives.max_by(&:time_int)
  # http://stackoverflow.com/a/26398284/358804
  encoded_url = Addressable::URI.encode_component(url, Addressable::URI::CharacterClasses::PATH)
  "https://web.archive.org/web/#{archive.timestamp}/#{encoded_url}"
end

# download_typhoeus(download_urls)
puts download_urls
