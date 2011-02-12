require 'pkg-wizard/command'
require 'pkg-wizard/logger'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'term/ansicolor'
require 'pkg-wizard/streaming_uploader'
require 'pp'

class String
  include Term::ANSIColor
end

module PKGWizard  
  class RemoteBuild < Command

    registry << { :name => 'remote-build', :klass => self }

    option :help,
      :short => "-h",
      :long => "--help",
      :description => "Show this message",
      :on => :tail,
      :boolean => true,
      :show_options => true,
      :exit => 0

    option :buildbot,
      :short => '-b URL',
      :long => '--buildbot URL'
    
    def self.perform
      cli = RemoteBuild.new
      cli.parse_options
      bbot_url = cli.config[:buildbot]
      pkg = ARGV.last

      # We need this to show the progress percentage 
      if pkg.nil? or not File.exist?(pkg)
        $stderr.puts "\nInvalid package argument. Make sure the specified file exists.\n\n"
        puts cli.opt_parser.help
        exit 1
      end
      if bbot_url.nil?
        $stderr.puts "\n --buildbot is required.\n\n"
        exit 1
      end
      fo = File.new(pkg)
      fsize = File.size(pkg)
      count = 0
      $stdout.sync = true
      line_reset = "\r\e[0K" 
      res = StreamingUploader.post(
        bbot_url + '/build/',
        { 'pkg' => fo }
      ) do |size|
        count += size
        per = (100*count)/fsize 
        if per %10 == 0
          print "#{line_reset}Uploading: #{(100*count)/fsize}% " 
        end
      end
      puts "#{line_reset}Progress: #{(100*count)/fsize}% [COMPLETE]"
    end

  end
end
