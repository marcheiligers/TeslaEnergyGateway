require 'net/http'
require 'uri'
require 'json'
require_relative 'indexer'
require_relative 'util'

include Util

indexer = Indexer.new
Dir['*.jsonl'].each do |file|
  File.read(file).split("\n").each do |json|
    data = JSON.parse(json)
    if data['timestamp']
      timestamp = data.delete('timestamp')
      data['@timestamp'] = Util.timestamp(Time.at(timestamp))
    end
    indexer.index(JSON.dump(data))
  end
end
