class Indexer
  def initialize(debug: false)
    @uri = URI.parse(ENV['GW_ES_URL'])
    @headers = {
      'Authorization' => "ApiKey #{ENV['GW_ES_API_KEY']}",
      'Content-Type' => 'application/json'
    }
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = true
    @debug = debug
  end

  def index(doc)
    request = Net::HTTP::Post.new('/energy_gateway/_doc/', @headers)
    request.body = JSON.dump(doc)
    response = @http.request(request)
    if @debug
      puts response.code
      puts response.body
    end
    JSON.parse(response.body)
  end
end
