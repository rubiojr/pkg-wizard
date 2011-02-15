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
      def find_job_path(name)
        (Dir["failed/job_*"] + Dir["success/job_*"]).find { |j| File.basename(j) == name }
      end

      post '/build/' do
        pkg = params[:pkg]
        if pkg.nil?
          Logger.instance.error '400: Invalid arguments. Needs pkg in post request'
          status 400
          "Missing pkg parameter.\n"
        else
          incoming_file = "incoming/#{pkg[:filename]}"
          $stdout.puts "Incoming file".ljust(40) + "#{pkg[:filename]}"
          FileUtils.cp pkg[:tempfile].path, incoming_file
          $stdout.puts "File saved".ljust(40) + "#{pkg[:filename]}"
        end
      end

      # list failed pkgs
      get '/job/failed' do
        max = params[:max] || 10
        jobs = (Dir["failed/job_*"].sort { |a,b| a <=> b }).map { |j| File.basename(j) }
        max = max.to_i
        if jobs.size > max.to_i
          jobs[- max..-1].to_yaml
        else
          jobs.to_yaml
        end
      end
      
      get '/job/stats' do
        fjobs = Dir["failed/job*"].size
        sjobs = Dir["output/job*"].size
        total_jobs = fjobs + sjobs
        { 
          :failed_jobs => fjobs,
          :successful_jobs => sjobs,
          :total_jobs => total_jobs
        }.to_yaml
      end

      # list failed pkgs
      get '/job/successful' do
        max = params[:max] || 10
        jobs = (Dir["output/job_*"].sort { |a,b| a <=> b }).map { |j| File.basename(j) }
        max = max.to_i
        if jobs.size > max.to_i
          jobs[- max..-1].to_yaml
        else
          jobs.to_yaml
        end
      end

      get '/job/rebuild/:name' do
        name = params[:name]
        job = find_job_path(name)
        if job.nil?
          status 404
        else
          $stdout.puts "Rebuilding job [#{name}]".ljust(40) + File.basename(Dir["#{job}/*.rpm"].first)
          FileUtils.cp Dir["#{job}/*.rpm"].first, 'incoming/'
        end
      end

      get '/job/current' do
        job = Dir['workspace/job*'].first
        if job
          File.read(job + '/meta.yml')
        else
          status 404
        end
      end

      get '/job/:name' do
        jname = params[:name]
        jobs = Dir['output/job_*'] + Dir['failed/job_*']
        found = false
        meta = ''
        if jname == 'all'
          found = true
          metas = []
          jobs.each do |j|
            mfile = j + '/meta.yml'
            if File.exist?(mfile)
              metas << YAML.load_file(mfile)
            else
              $stderr.puts "[WARNING] Meta file #{mfile} not found"
            end
          end
          meta = metas.to_yaml
        else
          jobs.each do |j|
            if File.basename(j) == jname
              found = true
              puts j + '/meta.yml'
              meta = File.read(j + '/meta.yml')
              break
            end
          end
        end
        status 404 if not found
        meta
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
      Dir.mkdir 'archive' if not File.exist?('archive')
      Dir.mkdir 'failed' if not File.exist?('failed')
      scheduler = Rufus::Scheduler.start_new
      scheduler.every '2s', :blocking => true do
        meta[:start_time] = Time.now
        queue = Dir['incoming/*.src.rpm'].sort_by {|filename| File.mtime(filename) }
        if not queue.empty?
          job_dir = "workspace/job_#{Time.now.strftime '%Y%m%d_%H%M%S'}"
          qfile = File.join(job_dir, File.basename(queue.first))
          job_time = Time.now.strftime '%Y%m%d_%H%M%S'
          $stdout.puts "Job accepted [job_#{job_time}]".ljust(40) + File.basename(qfile)
          result_dir = job_dir + '/result'
          FileUtils.mkdir_p result_dir
          meta[:source] = File.basename(queue.first)
          meta[:status] = 'building'
          File.open("workspace/job_#{job_time}/meta.yml", 'w') do |f|
            f.puts meta.to_yaml
          end
          FileUtils.mv queue.first, qfile
          $stdout.puts "Building pkg [job_#{job_time}]".ljust(40).yellow.bold +  "#{File.basename(qfile)}"

          rdir = nil
          begin
            PKGWizard::Mock.srpm :srpm => qfile, :profile => mock_profile, :resultdir => result_dir
            meta[:status] = 'ok'
            meta[:end_time] = Time.now
            meta[:build_time] = meta[:end_time] - meta[:start_time]
            $stdout.puts "Build OK [job_#{job_time}] #{meta[:build_time].to_i}s ".ljust(40).green.bold + "#{File.basename(qfile)}"
          rescue Exception => e
            meta[:status] = 'error'
            $stdout.puts "Build FAILED [job_#{job_time}]".ljust(40).red.bold  + "#{File.basename(qfile)}"
            File.open(job_dir + '/buildbot.log', 'w') do |f|
              f.puts "#{e.backtrace.join("\n")}"
              f.puts "#{e.message}"
            end
          ensure
            File.open(job_dir + '/meta.yml', 'w') do |f|
              f.puts meta.to_yaml
            end
            if meta[:status] == 'error'  
              FileUtils.mv job_dir, 'failed/'
              FileUtils.rm_f 'failed/last' if File.exist?('failed/last')
              FileUtils.ln_sf "#{File.basename(job_dir)}", "failed/last"
            else
              FileUtils.mv job_dir, 'output/'
              FileUtils.rm_f 'output/last' if File.exist?('output/last')
              FileUtils.ln_sf "#{File.basename(job_dir)}", "output/last"
            end
          end
        end
      end
      Webapp.run!
    end

  end
end
