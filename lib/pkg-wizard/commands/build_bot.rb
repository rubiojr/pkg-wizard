require 'pkg-wizard/command'
require 'pkg-wizard/rpm'
require 'pkg-wizard/logger'
require 'pkg-wizard/git'
require 'pkg-wizard/mock'
require 'pkg-wizard/utils'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'sinatra/base'
require 'rufus/scheduler'
require 'term/ansicolor'
require 'pp'
require 'yaml'
require 'daemons'
  

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
    
    option :port,
      :short =>  '-p PORT',
      :long => '--port PORT',
      :default => 4567

    option :daemonize,
      :long => '--daemonize',
      :default => false

    option :working_dir,
      :long => '--working-dir DIR'
    
    # not implemented
    option :log_format,
      :long => '--log-format FMT',
      :description => 'Log format to use (web, cli)',
      :default => 'cli'
    
    class Webapp < Sinatra::Base
      def find_job_path(name)
        (Dir["failed/job_*"] + Dir["success/job_*"]).find { |j| File.basename(j) == name }
      end

      post '/tag/:name' do
        name = params[:name]
        if name.nil? or name.strip.chomp.empty?
          status 400
          'Invalid tag'
        else
          File.open('tags/.tag', 'w') do |f|
            f.puts name
          end
          "Tagging #{name}..."
        end
      end

      post '/createrepo' do
        FileUtils.touch 'repo/.createrepo'
      end
      
      post '/createsnapshot' do
        FileUtils.touch 'snapshot/.createsnapshot'
      end
      
      post '/job/clean' do
        dir = params[:dir] || 'output'
        if dir == 'output'
          FileUtils.touch 'output/.clean'
        elsif dir == 'failed'
          FileUtils.touch 'failed/.clean'
        else
          $stderr.puts "WARNING: job/clean Unknown dir #{dir}. Ignoring."
        end
      end

      post '/build/' do
        pkg = params[:pkg]
        if pkg.nil?
          Logger.instance.error '400: Invalid arguments. Needs pkg in post request'
          status 400
          "Missing pkg parameter.\n"
        else
          incoming_file = "incoming/#{pkg[:filename]}"
          puts "Incoming file".ljust(40) + "#{pkg[:filename]}"
          FileUtils.cp pkg[:tempfile].path, incoming_file
          puts "File saved".ljust(40) + "#{pkg[:filename]}"
        end
      end

      # list failed pkgs
      get '/job/failed' do
        max = params[:max] || 10
        # Find failed jobs
        jobs = (Dir["failed/job_*"].sort { |a,b| a <=> b }).map { |j| File.basename(j) }

        # format job as job_XXXX_XXX (pkgname)
        jobs = jobs.map { |j| "#{j} (#{File.basename(Dir["failed/#{j}/*.src.rpm"].first(), '.src.rpm')})" }
        max = max.to_i
        if jobs.size > max.to_i
          jobs[- max..-1].to_yaml
        else
          jobs.to_yaml
        end
      end
      
      get '/server/stats' do
        fs = PKGWizard::Utils.filesystem_status
        { 
          :filesystem => fs,
        }.to_yaml
      end
      
      get '/job/stats' do
        fjobs = Dir["failed/job*"].size
        snapshots = Dir["snapshot/snapshot*"].size
        sjobs = Dir["output/job*"].size
        qjobs = Dir["incoming/*.src.rpm"].size
        cjobs = Dir["workspace/job_*"].size
        total_jobs = fjobs + sjobs
        { 
          :failed_jobs => fjobs,
          :successful_jobs => sjobs,
          :enqueued => qjobs,
          :total_jobs => total_jobs,
          :snapshots => snapshots,
          :building => cjobs
        }.to_yaml
      end

      # list successfully built pkgs
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

      #
      # Rebuild a previous job (It can be either successful or failed build)
      # 
      post '/job/rebuild/:name' do
        name = params[:name]
        job = find_job_path(name)
        if job.nil?
          status 404
        else
          puts "Rebuilding job [#{name}]".ljust(40) + File.basename(Dir["#{job}/*.rpm"].first)
          FileUtils.cp Dir["#{job}/*.rpm"].first, 'incoming/'
          FileUtils.rm_rf job
        end
      end

      # Get current building job (empty output if none)
      get '/job/current' do
        job = Dir['workspace/job*'].first
        if job
          File.read(job + '/meta.yml')
        else
          status 404
        end
      end


      # Get job info
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
      pwd = cli.config[:working_dir] || Dir.pwd
      pwd = File.expand_path pwd
      if cli.config[:daemonize]
        umask = File.umask
        Daemons.daemonize :app_name => 'build-bot', :dir_mode => :normal, :dir => pwd
        Dir.chdir pwd
        log = File.new("build-bot.log", "a")
        $stdout.reopen(log)
        $stderr.reopen(log)
        $stdout.sync = true
        $stderr.sync = true
        File.umask umask
      else
        Dir.chdir pwd
      end

      mock_profile = cli.config[:mock_profile]
      if not mock_profile
        $stderr.puts 'Invalid mock profile.'
        $stderr.puts cli.opt_parser.help
        exit 1
      end

      if not File.exist? '/usr/bin/rpmbuild'
        $stderr.puts 'rpmbuild command not found. Install it first.'
        exit 1
      end
      
      if not File.exist? '/usr/sbin/mock'
        $stderr.puts 'mock command not found. Install it first.'
        exit 1
      end

      meta = { :mock_profile  => mock_profile }
      
      
      Dir.mkdir 'incoming' if not File.exist?('incoming')
      Dir.mkdir 'output' if not File.exist?('output')
      Dir.mkdir 'workspace' if not File.exist?('workspace')
      Dir.mkdir 'archive' if not File.exist?('archive')
      Dir.mkdir 'failed' if not File.exist?('failed')
      Dir.mkdir 'snapshot' if not File.exist?('snapshot')
      Dir.mkdir 'tags' if not File.exist?('tags')
      FileUtils.ln_sf 'output', 'repo' if not File.exist?('repo')
      
      cleaner = Rufus::Scheduler.start_new
      cleaner.every '2s', :blocking => true do
        if File.exist?('failed/.clean')
          puts '* cleaning FAILED jobs'
          Dir["failed/job_*"].each do |d|
            FileUtils.rm_rf d
          end
          FileUtils.rm 'failed/.clean'
          FileUtils.rm_rf "failed/last"
        end
        if File.exist?('output/.clean')
          puts '* cleaning OUTPUT jobs'
          Dir["output/job_*"].each do |d|
            FileUtils.rm_rf d
          end
          FileUtils.rm 'output/.clean'
          FileUtils.rm_rf 'output/repodata'
          FileUtils.rm_rf 'output/last'
        end
      end

      # tag routine
      tag_sched = Rufus::Scheduler.start_new
      tag_sched.every '2s', :blocking => true do
        if File.exist?('tags/.tag')
          tag = File.read('tags/.tag').strip.chomp
          tag_dir = "tags/#{tag}"
          Dir.mkdir(tag_dir) if not File.exist?(tag_dir)
          Dir["output/*/result/*.rpm"].sort.each do |rpm|
            FileUtils.cp rpm, tag_dir 
          end
          puts "* create tag #{tag} repo START"
          output = `createrepo -q -o #{tag_dir} --update -d #{tag_dir} 2>&1`
          if $? != 0
            puts "create tag #{tag} operation failed: #{output}".red.bold
          else
            puts "* create tag #{tag} DONE"
          end
          FileUtils.rm 'tags/.tag'
        end
      end
      
      # createrepo snapshot
      snapshot_sched = Rufus::Scheduler.start_new
      snapshot_sched.every '2s', :blocking => true do
        if File.exist?('snapshot/.createsnapshot')
          puts '* snapshot START'
          stamp = Time.now.strftime '%Y%m%d_%H%M%S'
          snapshot_dir = "snapshot/snapshot_#{stamp}"
          Dir.mkdir snapshot_dir
          begin
            Dir["output/*/result/*.rpm"].sort.each do |rpm|
              FileUtils.cp rpm, snapshot_dir
            end
            puts '* snapshot DONE'
          rescue Exception => e
            $stderr.puts "snapshot operation failed".red.bold
          ensure
            FileUtils.rm 'snapshot/.createsnapshot'
          end
        end
      end

      # createrepo scheduler
      createrepo_sched = Rufus::Scheduler.start_new
      createrepo_sched.every '2s', :blocking => true do
        if File.exist?('repo/.createrepo')
          puts '* createrepo START'
          begin
            output = `createrepo -q -o repo/ --update -d output/ 2>&1`
            if $? != 0
              raise Exception.new(output)
            end
            puts '* createrepo DONE'
          rescue Exception => e
            $stderr.puts "createrepo operation failed".red.bold
            File.open('repo/createrepo.log', 'a') { |f| f.puts e.message }
          ensure
            FileUtils.rm 'repo/.createrepo'
          end
        end
      end

      # Build queue
      scheduler = Rufus::Scheduler.start_new
      scheduler.every '2s', :blocking => true do
        meta[:start_time] = Time.now
        queue = Dir['incoming/*.src.rpm'].sort_by {|filename| File.mtime(filename) }
        if not queue.empty?
          # Clean workspace first
          Dir["workspace/job_*"].each do |j|
            FileUtils.rm_rf j
          end
          job_dir = "workspace/job_#{Time.now.strftime '%Y%m%d_%H%M%S'}"
          qfile = File.join(job_dir, File.basename(queue.first))
          job_time = Time.now.strftime '%Y%m%d_%H%M%S'
          puts "Job accepted [job_#{job_time}]".ljust(40) + File.basename(qfile)
          result_dir = job_dir + '/result'
          FileUtils.mkdir_p result_dir
          meta[:source] = File.basename(queue.first)
          meta[:status] = 'building'
          File.open("workspace/job_#{job_time}/meta.yml", 'w') do |f|
            f.puts meta.to_yaml
          end
          FileUtils.mv queue.first, qfile
          puts "Building pkg [job_#{job_time}]".ljust(40).yellow.bold +  "#{File.basename(qfile)}"

          rdir = nil
          begin
            PKGWizard::Mock.srpm :srpm => qfile, :profile => mock_profile, :resultdir => result_dir
            meta[:status] = 'ok'
            meta[:end_time] = Time.now
            meta[:build_time] = meta[:end_time] - meta[:start_time]
            puts "Build OK [job_#{job_time}] #{meta[:build_time].to_i}s ".ljust(40).green.bold + "#{File.basename(qfile)}"
          rescue Exception => e
            meta[:status] = 'error'
            puts "Build FAILED [job_#{job_time}]".ljust(40).red.bold + "#{File.basename(qfile)}"
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
      Webapp.set :port => cli.config[:port]
      Webapp.run!
    end

  end
end
