require_relative "./load_test"
require_relative "./http_report"
require_relative "./test_factory"


class LoadRampUp
  attr_reader :tests
  
  
  def initialize(run_id, target_code, configuration)
    puts "Load Ramp Up created"
    if (run_id == nil)
    end
    @pids = []
    @run_id = run_id
    @target_code = target_code
    @factory = TestFactory.new
    @tests = {}
    @all_tests = []
    @configuration = configuration
    wasp_id = 0
    
    @configuration[:tests].each do |test_config|
      test_class = test_config[:test]
      
      initial_count = test_config[:initial]
      ramp_up_config = test_config[:ramp_up]
      final_count = ramp_up_config[:final]
      @tests[test_class] = []
      while (@tests[test_class].length < final_count)
        #                       (run_id, node_id, wasp_id, test, schedule_events, messenger)
        test = @factory.create_test(test_class, @target_code, test_config)
        load_test = LoadTest.new(self, run_id, nil, wasp_id, test, test_config, messenger)
        wasp_id += 1
        @tests[test_class] << load_test
        @all_tests << load_test
      end
      assign_schedules_to_tests(test_config,  @tests[test_class])
    end
    send_schedule_to_server(@configuration)
  end


  def send_schedule_to_server(configuration)
    (0..duration).each do |time|
      total_load = 0
      @all_tests.each do |test|
        action = test.schedule.current_action(time)
        if (action == :run)
          total_load += 1
        end
      end    
      report_load_to_server(@run_id, time, total_load)
    end
  end


  def duration
    last_time = 0
    @all_tests.each do |test|
      test_last_time = test.duration
      if (test_last_time > last_time)
        last_time = test_last_time
      end
    end
    return last_time
  end
  

  def find_total_loads
    load_at_times
    time = 0
    while (!done) do
      count = 0
      @all_tests.each do |test|
        if (test.current_action(time) == :run)
          count += 1
        end
      end
      time += 1
    end
  end
  
  
  def assign_schedules_to_tests(test_config, load_tests)
    ramp_up = test_config[:ramp_up]
    initial_count = test_config[:initial]
    
    load_tests.each do |test|
      test.schedule.add(0, :pause)
    end
    
    (0..initial_count - 1).each do |index|
      test = load_tests[index]
      test.schedule.add(0, :run)
    end
    
    rate = ramp_up[:rate]
    current_time = 0
    tests_started = initial_count
     while (tests_started < ramp_up[:final]) do
       current_time += rate
       load_tests[tests_started].schedule.add(current_time, :run)
       tests_started += 1
     end
     
     sustain_time = test_config[:sustain]
     current_time += sustain_time
     
     ramp_down = test_config[:ramp_down]
     final_count = ramp_down[:final]
     rate = ramp_down[:rate]
     while (tests_started > final_count) do
       load_tests[tests_started - 1].schedule.add(current_time, :pause)
       tests_started -= 1
       current_time += rate
     end
  end

  

  def run
    begin
       puts "Running Load test"
       @configuration[:tests].each do |test_config|
         test_name = test_config[:name]
         puts "Starting test: #{test_name}"
         @tests[test_name].each do |load_test|
           @pids << fork {
             #puts "Launching test: #{test_name} : #{load_test.wasp_id}"
             load_test.run
           }
         end
       end
       wait_for_kill_signal()
    rescue Interrupt => e
      puts "Interrupt signal received, quitting.  [#{e.class.name}]   #{e.message}"
    ensure
      kill_pids(@pids)
    end
    exit 0
  end

  
  def wait_for_kill_signal()
    while (true) do
      sleep 2000
    end
  end
  
  
  def kill_pids(pids)
    puts "Killing child processes"
    pids.each do |pid|
      Process.kill("INT", pid)
    end
  end
  
end
