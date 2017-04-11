# Require all files in custom test directory
this_dir_name = File.dirname(File.absolute_path(__FILE__))
Dir.glob(this_dir_name + '/custom/*') {|file| require file}

class TestFactory

  def initialize
  end
  
  def create_test(test_code, target_code, config)
    test_class = test_code.split(".").first
    test_object = Object::const_get(test_class).new
    test_object.test_code = test_code
    test_object.target_code = target_code
    raise "No parameters for target: :#{target_code}  Test: #{test_code}" unless (config[:params] != nil) && config[:params][target_code.to_sym]
    test_object.params = config[:params][target_code.to_sym]
    return test_object
  end
  
end