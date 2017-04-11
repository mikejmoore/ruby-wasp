require "net/http"
require "uri"
require "benchmark"
require_relative "http_report"
require_relative "load_test_schedule"
require 'logger'
require 'fileutils'

class LoadTest
  PASSED = "passed"
  FAILED = "failed"
  
  attr_reader :wasp_id, :start_time, :test
  attr_accessor :schedule
  
  def initialize(owner, run_id, node_id, wasp_id, test, schedule_events, messenger = nil)
    @owner = owner
    test.owner = self
    @schedule = LoadTestSchedule.new
    @schedule.load_json(schedule_events)
    @messenger = messenger
    @node_id = node_id
    @wasp_id = wasp_id
    @time_of_last_status_check = 0
    
    @test = test
    if (run_id == nil) || (run_id == 0)
      raise "No run_id specified for load test"
    end
    test_code = self.class.name
    @run_id = run_id
    @name = "Test for #{test.test_code}"
  end

  def log
    return @logger
  end
  
  def create_logger
    FileUtils.mkdir_p('./log/load') unless File.directory?('./log/load')
    FileUtils.mkdir_p("./log/load/run_#{@run_id}") unless File.directory?("./log/load/run_#{@run_id}")
    log_file = "./log/load/run_#{@run_id}/#{@test.class.name}_#{@wasp_id}.log"
    @logger = Logger.new(log_file)
    @logger.level = Logger::DEBUG
    @test.logger = @logger
  end
  
  def run
    create_logger()
    trap('INT') do
        puts "Wasp asked to die: #{test_code}:#{@wasp_id}  Pid: #{Process.pid}"
        #log.info "Wasp asked to die: #{test_code}:#{@wasp_id}  Pid: #{Process.pid}"
        exit 0
    end
      
    begin
      @start_time = Time.now
      @exit  = false
      while (!@exit)
        result = FAILED
        run_if_time_right(time_ellapsed_millis)
      end
      puts "End of run for wasp: #{@wasp_id}.  Duration: #{duration_millis}"
      log.info "End of run.  Duration: #{duration_millis}"
    rescue Interrupt => e
      log.warn "WASP KILL: #{test_code}:#{@wasp_id} Interrupt signal received, quitting.  [#{e.class.name}]   #{e.message}"
      puts "WASP KILL: #{test_code}:#{@wasp_id} Interrupt signal received, quitting.  [#{e.class.name}]   #{e.message}"
      @exit = true
    rescue Exception => exc
      log.warn "Exception in wasp: #{@wasp_id} .  [#{exc.class.name}]   #{exc.message}"
      puts "Exception in wasp: #{@wasp_id} .  [#{exc.class.name}]   #{exc.message}"
    ensure
      log.info "Wasp process exiting: #{test_code}:#{@wasp_id}  Pid: #{Process.pid}"
      puts "Wasp process exiting: #{test_code}:#{@wasp_id}  Pid: #{Process.pid}"
      exit 0
    end
  end

  
  def run_if_time_right(current_time_millis)
    benchmark_time = 0
    if (current_time_millis >= duration_millis)
      @exit = true
      puts "Time for LoadTest instance to die.  Ellapsed: #{current_time_millis}  Test duration: #{duration_millis}"
    else
      current_action = current_action_for_time(current_time_millis)
      if (current_action == :run)
        #puts "Time is right.  Test being performed"
        result = PASSED
        begin        
          benchmark_time = Benchmark.realtime {
            perform_test
          }
          log.info "Test completed normally in #{benchmark_time} seconds"
        rescue SystemExit => se
          log.warn "Caught system exit signal.  Exiting..."
          @exit = true
        rescue Exception => e
          result = FAILED
          log.error("Test (#{@test.class}) produced exception: #{e.class} #{e.message}")
          e.backtrace.each do |back|
            log.error(back)
          end
          puts "Test (#{@test.class}) produced exception: #{e.class} #{e.message} #{e.backtrace}"
        end
        
        custom_timing =  @test.timing
        if (custom_timing != nil)
          benchmark_time = custom_timing
        end
        @messenger.report_result(@run_id, @node_id, @test.test_code, @wasp_id, current_time_millis, benchmark_time, result)
      else
        #puts "Not running test.  current_action = #{current_action}"
        sleep 0.2
      end
      
      if (@exit == false)
        time_since_last_status_check = current_time_millis - @time_of_last_status_check
        if (time_since_last_status_check > 20*1000)
          @time_of_last_status_check = current_time_millis
          status = @messenger.status_for_test(@run_id, @wasp_id)
          if (status['run_status'] == "killed")
            log.warn "XXXXX  RUN HAS BEEN KILLED - KILLING WASP: #{@wasp_id}  XXXXXXX"
            @exit = true
          elsif (status['run_status'] == "finished")
            log.warn "XXXXX  RUN IS FINISHED - KILLING WASP: #{@wasp_id}  XXXXXXX"
            @exit = true
          end
        end
      end
    end
  end
  


  def duration_millis
    last_run_time = nil
    @schedule.events.each do |event|
      if (event[:action] == :run)
        last_run_time = nil
      else
        last_run_time = event[:time]
      end
    end
    
    if (last_run_time == nil)
      raise "This test never finishes on it's own"
    end
    return (last_run_time * 1000)
  end


  def time_ellapsed_millis
    time_ellapsed = (Time.now - @start_time) * 1000.0
    return time_ellapsed
  end

  def report_block_result(test_code, wasp_id, ellapsed_millis, benchmark_time, result, target_code = "unknown")
    @owner.report_block_result(test_code, wasp_id, ellapsed_millis, benchmark_time, result)
  end

  def current_action
    return current_action_for_time(time_ellapsed_millis)
  end
    
  def current_action_for_time(millis)
    current_action = schedule.current_action(millis / 1000)
    return current_action
  end
  
  def test_code
    return @test.test_code
  end
  
  def to_s
    return "I am only one wasp of a swarm.  ##{@wasp_id}"
  end

  def assert(value)
    if (value == false)
      raise "Assertion failed"
    end
  end  
  
  def perform_test
    @test.owner = self
    @test.set_up
    @test.run
    @test.pause_after_run
    @test.tear_down
  end
  
end



