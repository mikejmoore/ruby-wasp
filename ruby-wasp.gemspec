#gem build ruby-wasp.gemspec


Gem::Specification.new do |s|
  s.name        = 'ruby-wasp'
  s.email       = 'm.moore.denver@gmail.com'
  s.version     = '0.4.8'
  s.date        = '2015-06-29'
  s.summary     = "Ruby Load Tester"
  s.homepage      = 'https://github.com/mikejmoore/ruby-wasp'
  s.description = "Ruby Load Tester"
  s.license     = 'MIT'
  s.authors     = ["Mike Moore"]
  s.files       = Dir.glob("{bin,lib}/**/*")
  s.files       <<    "lib/wasp.rb"
  s.require_paths = ["lib", "lib/wasp"]
  s.homepage      = ''
  s.license       = 'MIT'
end
