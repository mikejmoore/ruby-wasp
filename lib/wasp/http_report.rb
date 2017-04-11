require "json"
require "net/http"

class HttpReport
  
  def initialize(server_address)
    @server = server_address
  end

  def server_address
     return "http://#{@server}/client"
  end
  
  def post(action, params)
    address = server_address + action
    puts "Posting to: #{address},  Params: #{params}"
    uri = URI.parse(server_address + action)
    begin
      response = Net::HTTP.post_form(uri, params)
    rescue Errno::ETIMEDOUT => error
      raise "Communication with server error: #{error}   Address: #{uri}"
    end
    
    if (response.code != "200")
      puts "Action: #{action} Response: #{response.code} Response body: #{response.body}"
      raise "Bad response from load http: #{response.code}  Response: #{response.body}"
    end
    return response.body
  end
  
  def node_finished(params)
    post "/node_finished", params
  end
  
  def report_result(run_id, node_id, test_code, wasp_id, run_at_millis, time, result)
    response = nil
    begin
      millis = nil
      if (time != nil)
        millis = time * 1000
      end
      response = post "/timing", {"run_at_millis" => run_at_millis, "time" => "#{millis}", "run_id" => run_id, "node_id" => node_id,"test_code" => test_code, "wasp_id" => wasp_id.to_s, "result" => result}
    rescue Exception => e
      puts "Error sending results (#{result} in #{millis}) to server(#{server_address}): #{e.message}"
    end
    return response
  end
  
  def status_for_test(run_id, wasp_id)
    # Checking for kill or finished run.
    response = post("/status_for_test", {"run_id" => run_id, 'wasp_id' => wasp_id})
    return JSON.parse(response)
  end

  def report_load_to_server(run_id, time, load_count)
    response = post "/load", {"run_id" => run_id, "time" => time, "load" => load_count}
  end

  def node_register(params)
    response = post("/node_register", params)
    data = JSON.parse(response)
    return data
  end
  
  def node_monitors(params)
    response = post("/node_monitors", params)
    data = JSON.parse(response)
    return data
  end
  

  def node_start?(params)
    response = post("/node_ask_to_start", params)
    data = JSON.parse(response)
    #puts "Node start response: #{data}"
    return data["start"]
  end

  def node_schedule(params)
    response = post("/node_schedule", params)
    data = JSON.parse(response)
    return data
  end
  
  def node_ready(params)
    response = post("/node_ready", params)
    return response
  end
  
  def run_create(params)
    node_count = params[:node_count]
    if (node_count == nil)
      node_count = 1
      params[:node_count] = node_count
    end

    if (params[:config_file_name] != nil)
      file_name = params[:config_file_name]
      config_from_file = ""
      begin      
        File.open(file_name, "r") do |f|
          config_from_file = f.read()
        end
        params[:config_file_name] = file_name
        # params[:configuration] = config_from_file
        configuration = eval(config_from_file)
        server_list = configuration[:servers]
        raise "Configuration lacks 'servers' list" unless (server_list != nil)
        target_server_address = server_list[params[:target_server].to_sym]
        raise "Configuration lacks entry in 'servers' list for ':#{params[:target_server]}'\n #{server_list}" unless target_server_address != nil
        params[:configuration] = configuration.to_s
        params[:config_code] = configuration[:code]
        raise "'duration' not specified for run." unless configuration[:duration] != nil
        params[:duration] = configuration[:duration]
        params[:name] = configuration[:name]
      rescue Exception => e
        raise "Exception reading config from file(#{File::absolute_path(file_name)}): #{e.message}"
      end
    end
    
    response = post("/run_create", params)
    data = JSON.parse(response)
    return data["run_id"].to_i
  end
  
  def run_node_info(params)
    response = post("/run_node_info", params)
    data = JSON.parse(response)
    return data
  end
  
end