require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "rpm-wizard"
  gem.version = File.read 'VERSION'
  gem.homepage = "http://github.com/rubiojr/rpm-wizard"
  gem.license = "MIT"
  gem.summary = %Q{RPM Wizards Tools}
  gem.description = %Q{Tools to manage,create and build RPM packages}
  gem.email = "rubiojr@frameos.org"
  gem.authors = ["Sergio Rubio"]
  gem.add_runtime_dependency 'SystemTimer'
  gem.add_runtime_dependency 'resque'
  gem.add_runtime_dependency 'git'
  #  gem.add_development_dependency 'rspec', '> 1.2.3'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "rpm-wizard #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
