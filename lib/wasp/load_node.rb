require_relative "./http_report"
require_relative "./load_test"
require_relative "./monitors/cpu_monitor.rb"
require_relative "./monitors/ram_monitor.rb"
require_relative "./monitors/file_io_monitor.rb"
require_relative "./monitors/network_monitor.rb"
require_relative "./test_factory.rb"

@@load_node_instance = nil

class LoadNode
  attr_reader :node_id, :schedule, :duration_millis
  attr_accessor :target_server, :target_code
  
  def self.instance
    return @@load_node_instance
  end
  
  def initialize(run_id, server_address, node_code = nil)
    if (@@load_node_instance != nil)
      raise "LoadNode instance initialized a second time"
    end
    @target_code = target_code
    @test_index = 1
    @messenger = nil
    @@load_node_instance = self
    @factory = TestFactory.new
    if (server_address == nil)
      # Perf tests don't require server
    else
      begin
        puts "Registering node"
        @run_id = run_id
        @child_pids = []
        @messenger = HttpReport.new(server_address)
        node_info = @messenger.node_register({run_id: @run_id, address: "#{Socket.gethostname}", code: node_code})
        if (node_info['configuration'] == nil)
          puts "Error starting node.  Did run already complete?"
        else  
          @configuration = eval(node_info['configuration'])
          @node_id = node_info["id"].to_i
          @node_code = node_info["code"]
          @target_code = node_info["target_server"]
          @target_server = @configuration[:servers][@target_code.to_sym]
          puts "Node registered: #{@node_id}   Code: #{@node_code}   Target server: #{@target_server}"
          @schedule = @messenger.node_schedule({node_id: @node_id})
          @load_tests = create_node_tests(@node_id, @schedule)
          @duration_millis = node_info["duration"]
          @messenger.node_ready({node_id: @node_id})
          wait_for_node_start_ok
          launch_node_tests
          wait_for_finish
          @messenger.node_finished({node_id: @node_id})
        end
      rescue Interrupt => e
        puts "NODE (#{@node_id}) - Interrupt signal received, quitting.  [#{self.class}]"
      rescue Exception => exc
        puts "Exception in node: #{exc.message} \n" + exc.backtrace.join("\n")
      ensure
        kill_child_processes
      end
      #exit 0
    end
  end

  def report_block_result(test_code, wasp_id, time_ellapsed, benchmark_time, result)
    @messenger.report_result(@run_id, @node_id, test_code, wasp_id, time_ellapsed, benchmark_time, result)
  end
  
  
  def write_pid_to_file(pid)  
    open('node_pids_#{@node_id}.pid', 'a') { |f|
      f.puts "#{pid}\n"
    }
  end
  
  def launch_node_tests
    @load_tests.each do |test|
      pid = fork {
        test.run
      }
      @child_pids << pid
      write_pid_to_file(pid)
    end
  end


  def wait_for_node_start_ok
    ok_to_start = false
    last_message_at = 0
    while (!ok_to_start)
      ok_to_start = @messenger.node_start?({node_id: @node_id})
      sleep 0.2
      if (Time.new.to_i - last_message_at > 5)
        puts "Node waiting for other nodes to start (#{@node_code})"
        last_message_at = Time.new.to_i
      end
    end
    puts "All Nodes Launched.  Node (#{@node_code}) can start now "
  end
  
  
  def wait_for_finish
      @start_time = Time.now.to_i
      quit = false
      while !quit
        sleep 10
        ellapsed_time = Time.now.to_i - @start_time
        if (ellapsed_time > (@duration_millis / 1000))
          quit = true
          puts "Node duration reached: #{@duration_millis} seconds.  Node quitting"
        else
          #puts "Node duration (#{ellapsed_time} secs) NOT reached: #{@duration_millis/1000} seconds."
        end
        @messenger.node_schedule({node_id: @node_id})
        
        status = @messenger.status_for_test(@run_id, nil)
        if (status['run_status'] == "killed")
          puts "XXXXX  RUN HAS BEEN KILLED - KILLING NODE: #{@wasp_id}  XXXXXXX"
          quit = true
        elsif (status['run_status'] == "finished")
          puts "XXXXX  RUN IS FINISHED - KILLING NODE: #{@wasp_id}  XXXXXXX"
          quit = true
        end
        
      end
      puts "Node finished.  ##{@node_code}"
  end
  
  
  def create_node_tests(node_id, node_schedule)
    wasp_id = 1
    load_tests = []

    puts "Node Schedule:"
    node_schedule.each do |test_schedule|
      test_name = test_schedule["test_name"]
      events = test_schedule["events"]
      sched_text = "Test: #{test_name}  Events: "
      events.each do |event|
        sched_text += "#{event['action'].capitalize} at #{event['time']} sec     "
      end
      test_config = find_config_for_test(test_name)
      test = @factory.create_test(test_name, @target_code, test_config)
      test.index = @test_index
      @test_index += 1
      
      load_test = LoadTest.new(self, @run_id, node_id, wasp_id, test, events, @messenger)
      load_tests << load_test
      wasp_id += 1
    end
    
    node_monitors = @messenger.node_monitors( {node_id: @node_id} )
    node_monitors.each do |monitor_config|
      type = monitor_config["type"]
      name = monitor_config["name"]
      duration = monitor_config["duration"].to_i / 1000
      if (name == nil)
        name = "#{type.capitalize} Monitor"
      end
      
      if (type == "network")
        puts "Config: #{monitor_config}"
        address = monitor_config["address"]
        monitor = NetworkMonitor.new(address)
      elsif (type == "cpu")
        monitor = CpuMonitor.new()
      elsif (type == "file.io")
        monitor = FileIoMonitor.new()
      elsif (type == "ram")
        monitor = RamMonitor.new()
      else
        raise "Do no know how to handle monitor type: #{type}   Name: #{name}"
      end
      
      events = [{"time" => "0", "action"  => "run"}, {"time" => "#{duration}", "action" => "pause"}]
      load_test = LoadTest.new(self, @run_id, node_id, wasp_id, monitor, events, @messenger)
      load_tests << load_test
      wasp_id += 1
    end
    
    return load_tests
  end
  
  def find_config_for_test(test_name)
    test_configs = @configuration[:tests]
    test_configs.each do |test_config|
      if (test_config[:test] == test_name)
        return test_config
      end
    end
  end

  
  def kill_child_processes
    # puts "=================================================================================="
    # puts "Node Finished: #{@node_id}"
    # puts "  Killing child PID's:  #{@child_pids}"
    # puts "=================================================================================="

    # trap("INT") do
    #   exit
    # end
    Process.kill('INT', -Process.getpgrp)
    # 
    # @child_pids.each do |pid|
    #   begin
    #     puts "Killing: #{pid}"
    #     Process.kill("INT", pid)
    #   rescue Exception => e
    #     puts "Exception killing pid #{pid}.  #{e.message}"
    #   end
    # end
  end
  
  
end