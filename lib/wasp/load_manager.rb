require_relative "./load_ramp_up"
require_relative "./load_reporter"
require_relative "./test_factory"
require_relative "./http_report"


class LoadManager
  attr_reader :run_id, :configuration

  def initialize(configuration, target_code)
    @configuration = configuration
  end

  def ramp_up
    puts "Load Manager - ramp_up"
    #command = "ruby load_test.rb"
    puts "Load Manager: #{Process.pid}"
    pids = []

    definition_code = configuration[:code]
    @server_address = ENV["SERVER"] || "localhost:2233"
    puts "Server address: #{@server_address}"
    ENV[""]


    if (ENV['SERVER'] == nil)
      puts "No 'SERVER' env specified, creating local/minimal server to store results"
      pids << fork {
        @reporter = LoadReporter.new({server: @server_address})
        while (@reporter.started == false)
          puts "Cannot find Wasp server"
          sleep 1
        end
      }
    else
      puts "Using existent 'SERVER': #{@server_address}"
    end

    @run_id = create_run({definition_code: definition_code})
    ramp_up = LoadRampUp.new(@run_id, @target_code, @configuration)

    pids << fork {
      ramp_up.run
    }

    quit = false
    while !quit
      begin
        system("stty raw -echo")
        str = STDIN.getc
      ensure
        system("stty -raw echo")
      end
      input = str.chr
      puts "You pressed: #{input}  ##{str.to_i}"
      if (input == "q")
        quit = true
        puts "=================================================================================="
        puts "DONE WITH RAMP UP"
        puts "  PID's:  #{pids}"
        puts "=================================================================================="
      end
    end
    kill_pids(pids)
  end


  def kill_pids(pids)
    puts "Killing child processes"
    pids.each do |pid|
      Process.kill("INT", pid)
    end
  end

end

# load_manager = LoadManager.new
# load_manager.ramp_up
