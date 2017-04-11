require_relative "./load_node.rb"
require_relative "./http_report.rb"
require 'singleton'

class ClientCommandLine
  attr_reader :run_id, :node_info_json

  def require_directory(directory_name)
    project_root = File.dirname(File.absolute_path(__FILE__))
    parent_directory = project_root + "/#{directory_name}"
    puts "Parent root: #{parent_directory}"
    Dir.glob("#{parent_directory}/*") do |file|
      require file
    end
  end

  def launch(args)
    require_directory("custom")
    puts "Wasp!"
    index = 0
    main_command = args[0]
    puts "Command: #{main_command}"
    index = 1
    if (main_command == "run")
      node_count = 1
      configuration_file_name = nil
      server_address = nil
      @target_server = nil
      while (index < args.length)
        arg = args[index]

        if (arg == "-n")
          index += 1
          node_count = args[index].to_i
        end

        if (arg == "-s")
          index += 1
          server_address = args[index]
        end

        if (arg == "-t")
          index += 1
          @target_server = args[index]
        end

        if (arg == "-c")
          index += 1
          configuration_file_name = args[index]
        end
        index += 1
        #puts "Looking at command line param: #{index}"
      end
      if (configuration_file_name == nil)
        raise "Failed to pass a -c parameter for config file"
      end

      if (@target_server == nil)
        raise "Must specify: -t 'target_server' on the command line"
      end

      uri = "http://#{server_address}/client"
      puts "Wasp server: #{uri}"
      create_run(node_count, configuration_file_name, server_address, @target_server)

      launch_node_command = "\nTo Start Nodes:\n"
      @node_info_json.each do |node_config|
        code = node_config["code"]
        launch_node_command += "  ruby wasp.rb node -c #{code} -s #{server_address} -r #{@run_id}\n"
      end

      puts "
  Run established.
  Run ID: #{@run_id}
  Waiting for #{node_count} nodes.
  Run details page:    http://#{server_address}/reports/run_details?run=#{@run_id}
  #{launch_node_command}
          "

    elsif (main_command == "node")
      @run_id = nil
      load_node = process_node_command(args)
    else
      help_text =
        "Usage:
           wasp run  -n /node_count/ -d /definition code/          {start with this process being the only node}
           wasp node m        {m is number of nodes, returns the run id for the node start up}
           wasp node -r /run_id/   {starts one of the nodes for a run}
        "
      puts help_text
    end
  end

  def create_run(node_count, configuration_file_name, wasp_server_address, target_server)
    messenger = HttpReport.new(wasp_server_address)
    @run_id = messenger.run_create({ node_count: node_count, config_file_name: configuration_file_name, target_server: target_server})
    @node_info_json = messenger.run_node_info({run_id: @run_id})
  end

  def process_node_command(args)
    while (index < args.length)
      arg = args[index]
      if (arg == "-r")
        index += 1
        @run_id = args[index].to_i
      elsif (arg == "-s")
        index += 1
        server_address = args[index]
      elsif (arg == "-c")
        index += 1
        node_code = args[index]
      end
      index += 1
    end

    if (@run_id == nil)
      raise "Failed to pass the run_id with -r for the node to run against."
    end
    if (server_address == nil)
      raise "Failed to pass the server address with -s for the node to run against."
    end

    load_node = launch_node(@run_id, server_address, node_code)
    return load_node
  end

  def launch_node(run_id, wasp_server_address, node_code)
    load_node = LoadNode.new(run_id, wasp_server_address, node_code)
  end

end
