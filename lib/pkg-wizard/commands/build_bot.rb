require 'pkg-wizard/command'
require 'pkg-wizard/rpm'
require 'pkg-wizard/logger'
require 'pkg-wizard/git'
require 'pkg-wizard/mock'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'sinatra/base'
require 'rufus/scheduler'
require 'term/ansicolor'
require 'pp'
require 'yaml'

class String
  include Term::ANSIColor
end

module PKGWizard  
  class BuildBot < Command

    registry << { :name => 'build-bot', :klass => self }

    option :help,
      :short => "-h",
      :long => "--help",
      :description => "Show this message",
      :on => :tail,
      :boolean => true,
      :show_options => true,
      :exit => 0

    option :mock_profile,
      :short =>  '-m PROF',
      :long => '--mock-profile PROF'
    
    class Webapp < Sinatra::Base
      post '/build/' do
        pkg = params[:pkg]
        if pkg.nil?
          Logger.instance.error '400: Invalid arguments. Needs pkg in post request'
          status 400
          "Missing pkg parameter.\n"
        else
          incoming_file = "incoming/#{pkg[:filename]}"
          $stdout.puts "Incoming file".ljust(40).bold.yellow + "#{pkg[:filename]}"
          FileUtils.cp pkg[:tempfile].path, incoming_file
          $stdout.puts "File saved".ljust(40).green.bold + "#{pkg[:filename]}"
        end
      end

    end
    
    def self.perform
      cli = BuildBot.new
      cli.banner = "\nUsage: rpmwiz build-bot (options)\n\n"
      cli.parse_options
      mock_profile = cli.config[:mock_profile]
      if not mock_profile
        $stderr.puts 'Invalid mock profile.'
        $stderr.puts cli.opt_parser.help
        exit
      end
      meta = { :mock_profile  => mock_profile }
      
      Dir.mkdir 'incoming' if not File.exist?('incoming')
      Dir.mkdir 'output' if not File.exist?('output')
      Dir.mkdir 'workspace' if not File.exist?('workspace')
      scheduler = Rufus::Scheduler.start_new
      scheduler.every '2s', :blocking => true do
        meta[:start_time] = Time.now
        queue = Dir['incoming/*.src.rpm'].sort_by {|filename| File.mtime(filename) }
        if not queue.empty?
          job_time = Time.now.strftime '%Y%m%d_%H%M%S'
          $stdout.puts "Job accepted [#{queue.size} Queued]".ljust(40).blue.bold + job_time
          job_dir = "workspace/job_#{Time.now.strftime '%Y%m%d_%H%M%S'}"
          result_dir = job_dir + '/result'
          FileUtils.mkdir_p result_dir
          meta[:source] = File.basename(queue.first)
          qfile = File.join(job_dir, File.basename(queue.first))
          FileUtils.mv queue.first, qfile
          $stdout.puts "Building pkg [#{job_time}]".ljust(40).yellow.bold +  "#{File.basename(qfile)}"

          begin
            PKGWizard::Mock.srpm :srpm => qfile, :profile => mock_profile, :resultdir => result_dir
            meta[:status] = 'ok'
            $stdout.puts "Finished building [#{job_time}]".ljust(40).green.bold + "#{File.basename(qfile)}"
          rescue Exception => e
            meta[:status] = 'error'
            $stdout.puts "Job failed [#{job_time}]".ljust(40).red.bold 
            File.open(job_dir + '/buildbot.log', 'w') do |f|
              f.puts "#{e.backtrace.join("\n")}"
              f.puts "#{e.message}"
            end
          ensure
            meta[:endtime] = Time.now
            File.open(job_dir + '/meta.yml', 'w') do |f|
              f.puts meta.to_yaml
            end
            FileUtils.mv job_dir, 'output/'
          end
        end
      end
      Webapp.run!
    end

  end
end
