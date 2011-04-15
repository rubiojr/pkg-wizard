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
require 'singleton'

module FakeColor
  def red; "<span style='color: red'>#{self}</span>"; end
  def blue; "<span style='color: blue'>#{self}</span>"; end
  def yellow; "<span style='color: yellow'>#{self}</span>"; end
  def green; "<span style='color: green'>#{self}</span>"; end
  def bold; "<b>#{self}</b>"; end
end

module PKGWizard  

  class NodeRunner
    @@logfile = '/dev/null'

    def self.logfile=(logfile)
      @@logfile = logfile
    end

    def self.available?
      not `which node`.strip.chomp.empty?
    end

    def self.kill
      Process.kill 15, @@proc.pid
    end

    def self.run
      public_dir = 'public'
      if not defined? @@proc
        puts '* starting NODE.JS...'
        @@proc = IO.popen("node public/server.js #{@@logfile}")
      end
    end
  end

  class BuildBotConfig
    include Singleton
    attr_accessor :mock_profile

    def initialize
      @mock_profile = "epel-5-x86_64"
    end
  end

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
      :long => '--mock-profile PROF',
      :description => 'Default Mock Profile'
    
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

    option :log_server_port,
      :long => '--log-server-port PORT',
      :description => 'log server port (60001 default)',
      :default => '60001'
    
    class Webapp < Sinatra::Base
      def find_job_path(name)
        (Dir["failed/job_*"] + Dir["success/job_*"]).find { |j| File.basename(j) == name }
      end

      get '/' do
        File.read(File.join(File.dirname(__FILE__), '/../../../resources/public/build-bot/index.html'))
      end

      post '/tag/:name' do
        name = params[:name]
        profile = params[:mock_profile]
        meta = {
          :name => name,
          :mock_profile => profile
        }
        if name.nil? or name.strip.chomp.empty?
          status 400
          'Invalid tag'
        else
          File.open('tags/.tag', 'w') do |f|
            f.puts meta.to_yaml 
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
        dir = params[:dir]
        if dir == 'output'
          FileUtils.touch 'output/.clean'
        elsif dir == 'failed'
          FileUtils.touch 'failed/.clean'
        elsif dir.nil?
          FileUtils.touch 'output/.clean'
          FileUtils.touch 'failed/.clean'
        else
          $stderr.puts "WARNING: job/clean Unknown dir #{dir}. Ignoring."
        end
      end

      post '/build/' do
        pkg = params[:pkg]
        build_profile = params[:mock_profile] || BuildBotConfig.instance.mock_profile
        metadata = {
          :mock_profile => build_profile
        }

        if pkg.nil?
          Logger.instance.error '400: Invalid arguments. Needs pkg in post request'
          status 400
          "Missing pkg parameter.\n"
        else
          incoming_file = "incoming/#{pkg[:filename]}"
          puts "* incoming file".ljust(40) + "#{pkg[:filename]}"
          FileUtils.cp pkg[:tempfile].path, incoming_file
          File.open("incoming/#{pkg[:filename]}.metadata", 'w') do |f|
            f.puts metadata.to_yaml
          end
        end
      end

      # log
      get '/log' do
        if NodeRunner.available?
          NodeRunner.run
          sleep 0.5
          index = 'public/index.html'
          File.read index
        else
          'node.js is not installed: Real time logs disabled :('
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
      cli.banner = "\nUsage: pkgwiz build-bot (options)\n\n"
      cli.parse_options

      ## Node.JS log server stuff
      public_dir = File.join(File.dirname(__FILE__), '/../../../resources/public/')
      node_port = cli.config[:log_server_port]
      if File.exist?('public')
        FileUtils.rm_rf 'public'
      end
      FileUtils.cp_r public_dir, 'public'
      html = File.read('public/index.html.tmpl').gsub('@@NODEJSPORT@@', node_port)
      serverjs = File.read('public/server.js.tmpl').gsub('@@NODEJSPORT@@', node_port)
      File.open 'public/index.html', 'w' do |f|
        f.puts html
      end
      File.open 'public/server.js', 'w' do |f|
        f.puts serverjs 
      end

      if cli.config[:log_format] == 'web'
        String.class_eval do include FakeColor; end
      else
        String.class_eval do include Term::ANSIColor; end
      end

      pwd = cli.config[:working_dir] || Dir.pwd
      NodeRunner.logfile = (cli.config[:working_dir] || Dir.pwd) + '/build-bot.log'
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
      BuildBotConfig.instance.mock_profile = mock_profile
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
          tag_meta = YAML.load_file 'tags/.tag' rescue nil
          if tag_meta
            tag_dir = "tags/#{tag_meta[:name]}"
            tag_mock_profile = tag_meta[:mock_profile]

            tag_pkgs = []
            Dir["output/*/result/*.rpm"].sort.each do |rpm|
              p = YAML.load_file(File.join(File.dirname(rpm), '/../meta.yml'))[:mock_profile]
              if p == tag_mock_profile or tag_mock_profile.nil?
                tag_pkgs << rpm
              end
            end
                
            if not tag_pkgs.empty?
              puts "* create tag #{tag_meta[:name]} repo START"
              Dir.mkdir(tag_dir) if not File.exist?(tag_dir)
              tag_pkgs.each do |rpm|
                FileUtils.cp rpm, tag_dir 
              end
              output = `createrepo -q -o #{tag_dir} --update -d #{tag_dir} 2>&1`
              if $? != 0
                puts "create tag #{tag_meta[:name]} operation failed: #{output}".red.bold
              else
                puts "* create tag #{tag_meta[:name]} DONE"
              end
            else
              puts "* WARNING: trying to create a tag with no packages."
            end
            FileUtils.rm 'tags/.tag'
          else
            puts "* ERROR: error creating tag, could not parse tag metadata."
          end
        else
          
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
        meta[:mock_profile] = mock_profile
        queue = Dir['incoming/*.src.rpm'].sort_by {|filename| File.mtime(filename) }
        if not queue.empty?
          # Clean workspace first
          Dir["workspace/job_*"].each do |j|
            FileUtils.rm_rf j
          end
          job_dir = "workspace/job_#{Time.now.strftime '%Y%m%d_%H%M%S'}"
          imeta_file = "#{queue.first}.metadata"
          qfile = File.join(job_dir, File.basename(queue.first))
          if File.exist?(imeta_file)
            begin
            imeta = YAML.load_file(imeta_file)
            if imeta
              m = YAML.load_file(imeta_file)
              meta[:mock_profile] = m[:mock_profile] || BuildBotConfig.mock_profile
            end
            rescue Exception
              puts "* ERROR: parsing #{queue.first} metadata"
            end
            FileUtils.rm imeta_file 
          else
            puts "* WARNING: #{queue.first} does not have metadata!"
          end
          job_time = Time.now.strftime '%Y%m%d_%H%M%S'
          result_dir = job_dir + '/result'
          FileUtils.mkdir_p result_dir
          meta[:source] = File.basename(queue.first)
          meta[:status] = 'building'
          File.open("workspace/job_#{job_time}/meta.yml", 'w') do |f|
            f.puts meta.to_yaml
          end
          FileUtils.mv queue.first, qfile
          puts "Building pkg [job_#{job_time}][#{meta[:mock_profile]}] ".ljust(40).yellow.bold +  "#{File.basename(qfile)}"

          rdir = nil
          begin
            PKGWizard::Mock.srpm :srpm => qfile, :profile => meta[:mock_profile], :resultdir => result_dir
            meta[:status] = 'ok'
            meta[:end_time] = Time.now
            meta[:build_time] = meta[:end_time] - meta[:start_time]
            puts "Build OK [job_#{job_time}][#{meta[:mock_profile]}] ".ljust(40).green.bold + "#{File.basename(qfile)}"
          rescue Exception => e
            meta[:status] = 'error'
            puts "Build FAILED [job_#{job_time}][#{meta[:mock_profile]}]".ljust(40).red.bold + "#{File.basename(qfile)}"
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
      Webapp.set :public => 'public'
      Webapp.run!
      at_exit do 
        NodeRunner.kill
      end 
    end

  end
end
