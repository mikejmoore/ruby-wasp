require 'webrick'

class LoadReporter
  attr_reader :started
  include WEBrick

  def initialize(params)
    puts "Initializing Load Reporter"
    @started = false
    @server_address = params[:server]
    @current_load = 0
    file_name = "data_#{Time.now.to_i}.txt"
    @out_file = File.new("out.txt", "w")
    port = params[:port] || 2233
    puts "Starting server: http://#{Socket.gethostname}:#{port}"
    server = HTTPServer.new(:Port=>2233,:DocumentRoot=>Dir::pwd )
    trap("INT") {
      puts "Server going down" 
      server.shutdown 
    }
    
    server.mount_proc '/' do |request, response|
      response.body = process_request(request)
    end
    server.start  
    @started = true
  end
  
  
  def process_request(request)
  response = "
      Current Load: #{@current_load}
      Query String: #{request.query_string}
    "
       
    request.query.collect { | key, value | 
      #f.write("#{key}: #{value}\n") 
      if (key == "load")
        @current_load = value.to_i
        response += "Current load changed to: #{@current_load}"
      end
      response += "#{key}: #{value}\n"
    }
    puts "RESPONSE: #{response}"
    return response
  end
  
end
