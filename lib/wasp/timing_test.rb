require "uri"
require "benchmark"


class TimingTest
  attr_accessor :params, :index, :owner, :test_code, :logger, :target_code
  
  def initialize
    @params = {}
    @index = 0
    @owner = nil
    @test_code = nil
    @target_code = nil
  end
  
  def set_up
  end
  
  def tear_down
  end
  
  def run
    raise "Not Implemented"
  end
  
  def server_url
    url = LoadNode.instance.target_server
    if (url == nil)
      raise "target_server not specified when starting main process"
    end
    return url
  end
  
  def ellaped_millis
    @owner.time_ellapsed_millis
  end

  def log
    return @logger
  end
  
  def time_block(code)
    start_time = Time.now
    begin
      yield
      end_time = Time.now
      block_time = (end_time.to_f - start_time.to_f) * 1000
      @owner.report_block_result(code, @index, @owner.time_ellapsed_millis, block_time, LoadTest::PASSED, target_code)
    rescue Exception => e
      log.error("Exception running timing block (#{code}) test: #{e.message}")
      end_time = Time.now
      block_time = (end_time.to_f - start_time.to_f) * 1000
      @owner.report_block_result(code, @index, @owner.time_ellapsed_millis, block_time, LoadTest::FAILED, target_code)
      raise e
    end
  end


  def assert(value)
    if (value == false)
      puts "Assertion failed"
      raise "Assertion failed"
    end
  end  
  
  def pause_after_run
    # Default is no pause
  end
  
  def timing
    # LoadTest times the run method and uses that timing unless the instance of TimingTest timing method returns a non-nil time.
    return nil
  end
  
end

