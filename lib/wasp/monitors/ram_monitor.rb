require_relative "../timing_test"


class RamMonitor < TimingTest

  def initialize
    @sleep_seconds = 4
  end

  def run
    
  end

  def pause_after_run
    sleep @sleep_seconds
  end


  def test_code
    return ("monitor.ram")
  end

end


