require "uri"
require "benchmark"
require_relative "../timing_test"


class CpuMonitor < TimingTest

  def initialize
    @sleep_seconds = 4
  end

  def run
    a = 5000
    (0..1000).each do |i|
      a /= 2.0
    end
  end

  def pause_after_run
    sleep @sleep_seconds
  end


  def test_code
    return ("monitor.cpu")
  end

end


