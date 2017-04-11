require "uri"
require "benchmark"
require_relative "../timing_test"


class FileIoMonitor < TimingTest

  def initialize
    @sleep_seconds = 4
  end

  def run
    file_name = "./log/file_io_bench_#{Time.now.to_i}.dat"
    (1..200).each do |i|
      File.open(file_name, 'w') { |file| 
        (1..1000).each do |i|
          file.write("Test text #{i} aohoasihdf oiahsdf pohiasdfha oisdhf aiousdfgho iausgdf oaia aiusdhfia hdfihdsfi ahsdfi ahudf \n") 
          file.flush
        end
      }
    
      File.readlines(file_name).each do |line|      
        if (!line.start_with? "Test text")
          raise "Error reading back file"
        end
      end
      File.delete(file_name)
    end
  end

  def pause_after_run
    sleep @sleep_seconds
  end


  def test_code
    return ("monitor.file")
  end

end


