require_relative "../timing_test"
require 'net/ping'


class NetworkMonitor < TimingTest
  attr_accessor :address

  def initialize(address)
    @sleep_seconds = 4
    @address = address
  end

  def timing
    return @timing
  end

  def run
    output = ""
    begin
      timing = 0
      pinger = Net::Ping::External.new
      (1..10).each do
        pinger.ping(@address)
        timing += (pinger.duration * 1000.0)
      end
      puts "Ping timing for 10 pings: #{timing}"
      @timing = timing
    rescue Exception => e
      @timing = nil
      puts "Error pinging address: #{@address}    =>   #{output}"
      raise "Error pinging address: #{@address}    =>   #{output}"
    end
  end
  
  #64 bytes from localhost (127.0.0.1): icmp_req=4 ttl=64 time=0.015 ms
  #64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.018 ms

  def pause_after_run
    sleep @sleep_seconds
  end

  def test_code
    return ("monitor.network")
  end

end


