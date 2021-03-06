require 'pkg-wizard/command'
require 'pkg-wizard/logger'
require 'pkg-wizard/streaming_downloader'
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
      :description => 'pkg-wizard build-bot URL',
      :long => '--buildbot URL'
    
    option :buildbot_port,
      :short => '-p PORT',
      :description => 'pkg-wizard build-bot PORT (default 4567)',
      :long => '--buildbot-port PORT',
      :default => 4567

    option :source,
      :short => '-s SOURCE',
      :long => '--source SRC'

    option :tmpdir,
      :short => '-t TEMP',
      :long => '--tmpdir TEMP',
      :description => 'Directory for downloaded files to be put',
      :default => '/tmp'
    
    option :mock_profile,
      :short => '-m ',
      :long => '--mock-profile PROFILE',
      :description => 'Mock profile to use for building'
    
    def self.perform
      cli = RemoteBuild.new
      cli.banner = "\nUsage: pkgwiz remote-build (options)\n\n"
      pkgs = cli.parse_options
      bbot_host = cli.config[:buildbot]
      bbot_port = cli.config[:buildbot_port]
      bbot_url = "http://#{bbot_host}:#{bbot_port}"
      if bbot_host.nil?
        $stderr.puts "\n--buildbot is required.\n"
        puts cli.opt_parser.help
        exit 1
      end
      downloaded_pkgs = []
      pkgs.reject! do |p|
        if p =~ /http:\/\//
          pkg = URI.parse(p).path.split("/").last
          $stdout.puts "Downloading: #{pkg}"
          downloaded_pkgs << download_from_url(p,cli.config[:tmpdir]) 
          true
        elsif p =~ /git:\/\//
          require 'tmpdir'
          d = Dir.mktmpdir

          # Fetch the package sources using Git
          $stdout.puts "Fetching package sources from Git..."
          PKGWizard::GitRPM.fetch p, d
          spec = Dir["#{d}/*.spec"].first
          pwd = Dir.pwd
          Dir.chdir d

          # Download sources
          source = cli.config[:source]
          if source and source =~ /http:\/\//
            url = URI.parse(source)
            $stdout.puts "Downloading source #{File.basename(url.path)}..."
            download_from_url(source,d) 
            puts
          end

          # Create the SRPM
          $stdout.puts "Creating SRPM for #{spec}..."
          srpm = SRPM.create
          downloaded_pkgs << srpm
          Dir.chdir pwd
          FileUtils.rm_rf d
          true
        else
          false
        end
      end
      pkgs += downloaded_pkgs

      #
      # If no packages are specified, we assume we need to create
      # and SRPM from current dir
      #
      created_srpms = []
      if pkgs.empty? and Dir["*.spec"].size > 0
        spec = Dir["*.spec"].first
        $stdout.puts "Creating SRPM for #{spec}..."
        srpm = SRPM.create
        created_srpms << srpm
      end
      pkgs += created_srpms

      # We need this to show the progress percentage 
      if pkgs.empty?
        $stderr.puts "\nNo packages found.\n\n"
        puts cli.opt_parser.help
        exit 1
      end
      pkgs.each do |pkg|
        fo = File.new(pkg)
        fsize = File.size(pkg)
        count = 0
        $stdout.sync = true
        line_reset = "\r\e[0K" 
        params = {}
        params[:mock_profile] = cli.config[:mock_profile] if cli.config[:mock_profile]
        params[:pkg] = fo
        res = StreamingUploader.post(
          bbot_url + '/build/',
          params
        ) do |size|
          count += size
          per = (100*count)/fsize 
          if per %10 == 0
            print "#{line_reset}Uploading:".ljust(40) + "[#{count}/#{fsize}]" 
          end
        end
        puts "#{line_reset}Uploading: #{File.basename(pkg)} ".ljust(40) + "[#{fsize}] [COMPLETE]"
      end
    end

    def self.download_from_url(url, tmpdir = '/tmp')
      uri = URI.parse(url)
      remote_pkg = uri.path.split('/').last
      d = StreamingDownloader.new
      f = "#{tmpdir}/#{remote_pkg}"
      tmpfile = File.new(f, 'w')
      d.download!(url, tmpfile)
      tmpfile.close
      f
    end

  end
end
