# https://github.com/jasonacox/pypowerwall/blob/main/pypowerwall/__init__.py

require 'net/http'
require 'uri'
require 'json'

class Gateway
  API = {
    login: '/api/login/Basic',
    level: '/api/system_status/soe',
    power: '/api/meters/aggregates'
  }.freeze

  CACHE_FILE = 'gateway.cache'
  CACHE_TTL = 60 * 60 * 24 # 24 hours

  def initialize(debug: false)
    @debug = debug

    pw_ip = '192.168.50.88'
    uri = URI.parse("https://#{pw_ip}")
    @http = Net::HTTP.new(uri.host, uri.port)
    @http.use_ssl = true
    # @http.ssl_version = 'SSLv3'
    # @http.ciphers = 'AEAD-CHACHA20-POLY1305-SHA256'
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    cache_login
  end

  def level
    # Battery Level Percentage
    # Args:
    #     scale = If True, convert battery level to app scale value
    #     Note: Tesla App reserves 5% of battery = ( (batterylevel / 0.95) - (5 / 0.95) )
    # {"percentage":70.25318037539677}
    perc = request(:level)['percentage']
    {
      real: perc,
      app: (perc / 0.95) - (5 / 0.95)
    }
  end

  def power
    # {"site":{"last_communication_time":"2023-07-02T13:04:35.937341697-07:00","instant_power":18,"instant_reactive_power":-51,"instant_apparent_power":54.08326913195984,"frequency":0,"energy_exported":11580012.119935803,"energy_imported":16979421.483619817,"instant_average_voltage":213.57052482728042,"instant_average_current":17.438000000000002,"i_a_current":0,"i_b_current":0,"i_c_current":0,"last_phase_voltage_communication_time":"0001-01-01T00:00:00Z","last_phase_power_communication_time":"0001-01-01T00:00:00Z","last_phase_energy_communication_time":"0001-01-01T00:00:00Z","timeout":1500000000,"num_meters_aggregated":1,"instant_total_current":17.438000000000002},"battery":{"last_communication_time":"2023-07-02T13:04:35.980333775-07:00","instant_power":-1210,"instant_reactive_power":-10,"instant_apparent_power":1210.0413216084812,"frequency":59.986000000000004,"energy_exported":15720650,"energy_imported":17826310,"instant_average_voltage":247.16666666666669,"instant_average_current":24.5,"i_a_current":0,"i_b_current":0,"i_c_current":0,"last_phase_voltage_communication_time":"0001-01-01T00:00:00Z","last_phase_power_communication_time":"0001-01-01T00:00:00Z","last_phase_energy_communication_time":"0001-01-01T00:00:00Z","timeout":1500000000,"num_meters_aggregated":3,"instant_total_current":24.5},"load":{"last_communication_time":"2023-07-02T13:04:35.937341697-07:00","instant_power":7756.5,"instant_reactive_power":-87.75,"instant_apparent_power":7756.996346041424,"frequency":0,"energy_exported":0,"energy_imported":47983936.317730494,"instant_average_voltage":213.57052482728042,"instant_average_current":36.31821388402199,"i_a_current":0,"i_b_current":0,"i_c_current":0,"last_phase_voltage_communication_time":"0001-01-01T00:00:00Z","last_phase_power_communication_time":"0001-01-01T00:00:00Z","last_phase_energy_communication_time":"0001-01-01T00:00:00Z","timeout":1500000000,"instant_total_current":36.31821388402199},"solar":{"last_communication_time":"2023-07-02T13:04:35.980203281-07:00","instant_power":8956,"instant_reactive_power":-42,"instant_apparent_power":8956.098480923487,"frequency":0,"energy_exported":44723101.20994558,"energy_imported":32914.25589910057,"instant_average_voltage":213.89095422668066,"instant_average_current":36.272,"i_a_current":0,"i_b_current":0,"i_c_current":0,"last_phase_voltage_communication_time":"0001-01-01T00:00:00Z","last_phase_power_communication_time":"0001-01-01T00:00:00Z","last_phase_energy_communication_time":"0001-01-01T00:00:00Z","timeout":1500000000,"num_meters_aggregated":1,"instant_total_current":36.272}}
    json = request(:power)
    {
      grid: json['site']['instant_power'],
      solar: json['solar']['instant_power'],
      battery: json['battery']['instant_power'],
      house: json['load']['instant_power']
    }
  end

  def request(api)
    request = Net::HTTP::Get.new(API[api], { 'Cookie' => @cookies })
    response = @http.request(request)
    if @debug
      puts response.code
      puts response.body
    end
    JSON.parse(response.body)
  end

  def cache_login
    if File.exist?(CACHE_FILE)
      data = JSON.parse(File.read(CACHE_FILE))
      return @cookies = data['cookies'] if data['timestamp'] > Time.now.to_i + CACHE_TTL
    end

    login
    File.open(CACHE_FILE, 'w') { |f| f.puts JSON.dump({ cookies: @cookies, timestamp: Time.now.to_i }) }
  end

  def login
    body = {
      'username' => 'customer',
      'password' => ENV['GW_PWD'],
      'email' => 'foo@bar.baz',
      'clientInfo' => {
        'timezone' => 'UTC -7'
      }
    }

    request = Net::HTTP::Post.new(API[:login])
    request.body = URI.encode_www_form(body)
    response = @http.request(request)

    if response.code != '200'
      puts "Error #{response.code}"
      puts response.body
    else
      all_cookies = response.get_fields('set-cookie')
      @cookies = all_cookies.map do |cookie|
        cookie.split('; ')[0]
      end.join('; ')
    end
  end
end

class Slack
  def initialize
    @uri = URI.parse(ENV['GW_SLACK'])
    @http = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl = true
  end

  def alert(message)
    notify(message, alert: true)
  end

  def info(message)
    notify(message, alert: false)
  end

  def notify(message, alert: true) # rubocop:disable Metrics/MethodLength
    body = {
      'channel' => alert ? '#homestuff' : '#homestuff-monitor',
      'username' => 'Teslabot',
      'text' => message,
      'icon_emoji' => ':robot_face:'
    }

    request = Net::HTTP::Post.new(@uri.path)
    request.body = JSON.dump(body)
    response = @http.request(request)

    if response.code != '200'
      puts "Error #{response.code}"
      puts response.body
    end
  end
end

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

class Poller
  POLL_EVERY = 59 # Once a minute with ~1s request time
  RETRY_AFTER = 5

  def initialize
    @gw = Gateway.new
    @slack = Slack.new
    @indexer = Indexer.new
    @producing = true
  end

  def draw(num)
    arrow = num > 0 ? '→' : '←'
    str = (num / 1_000.0).round(1).abs.to_s
    str += '.0' unless str.include?('.')
    "#{arrow} #{str}kW"
  end

  # ls /System/Library/Sounds/ | awk '{print $1}' | while read sound; do printf "using $sound...\n"; afplay /System/Library/Sounds/$sound; sleep 0.5; done
  # ls /System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds/ | awk '{print $1}' | while read sound; do printf "using $sound...\n"; afplay /System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds/$sound; sleep 0.5; done

  def play(sound)
    `afplay /System/Library/PrivateFrameworks/ScreenReader.framework/Versions/A/Resources/Sounds/#{sound}.aiff &`
  end

  def timestamp
    # 2020-05-23T18:17:56.715Z
    Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.000Z')
  end

  def poll
    @gw.power.merge(@gw.level).merge({ '@timestamp': timestamp }).tap do |data|
      File.open("data-#{Time.now.strftime('%Y-%m-%d')}.jsonl", 'a') { |f| f.puts JSON.dump(data) }
    end
  rescue => e
    puts "Error: #{e.message}"
    count_down(RETRY_AFTER)
    retry
  end

  def count_down(time)
    while time > 0
      print "\r#{(time -= 1) + 1}s  "
      sleep 1
    end
    puts
  end

  def start
    while true
      data = poll

      if @producing && data[:solar] < 1
        @producing = false
        play('Error')
        @slack.alert(':no_entry_sign: No production :bangbang:')
      elsif !@producing && data[:solar] > 1
        @producing = true
        play('Focus2')
        @slack.alert(":sunny: Production started :sunny: #{draw(data[:solar])}")
      end

      if [0, 15, 30, 45].include?(Time.now.min)
        @slack.info(":sunny: #{draw(data[:solar])}  :battery: #{draw(data[:battery])} [#{data[:app].round(1)}%]  :house: #{draw(data[:house])}  :zap: #{draw(data[:grid])}")
      end

      puts `clear`
      puts "☀️  #{draw(data[:solar])} #{@producing ? '' : '‼️'}"
      puts "🔋 #{draw(data[:battery])} [#{data[:app].round(1)}%]"
      puts "🏠 #{draw(data[:house])}"
      puts "⚡️ #{draw(data[:grid])}"

      @indexer.index(data)

      count_down(POLL_EVERY)
    end
  rescue => e
    puts "Error: #{e.message}"
    count_down(RETRY_AFTER)
    retry
  end
end

Poller.new.start

# poller = Poller.new
# doc = {
#   'grid' => 0.0,
#   'solar' => 0.0,
#   'battery' => 0.0,
#   'house' => 0.0,
#   'real' => 0.0,
#   'app' => 0.0,
#   '@timestamp' => poller.timestamp
# }
# indexer = Indexer.new(debug: true)
# indexer.index(doc)
