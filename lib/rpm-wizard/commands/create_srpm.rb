require 'rpm-wizard/command'
require 'rpm-wizard/rpm'
require 'rpm-wizard/logger'
require 'rpm-wizard/git'
require 'tmpdir'
require 'fileutils'
require 'uri'

module RPMWizard  
  class CreateSrpm < Command
    registry << { :name => 'create-srpm', :klass => self }

    option :help,
      :short => "-h",
      :long => "--help",
      :description => "Show this message",
      :on => :tail,
      :boolean => true,
      :show_options => true,
      :exit => 0
    
    option :gitrepo,
      :short => '-g REPO',
      :long => '--gitrepo REPO',
      :description => 'Git repo URL to fetch the package sources from'

    option :workspace,
      :short => '-w DIR',
      :long => '--workspace DIR',
      :description => 'Git repo URL to fetch the package sources from'

    option :resultdir,
      :short => '-r DIR',
      :long => '--resultdir DIR',
      :description => 'Path for resulting files to be put'

    def self.perform
      cmd = CreateSrpm.new
      cmd.banner = "\nUsage: rpmwiz create-srpm (options)\n\n"
      cmd.parse_options
      repo = cmd.config[:gitrepo]
      workspace = cmd.config[:workspace] || "/tmp/rpmwiz-#{Time.now.to_i}"
      FileUtils.mkdir_p(workspace) if not File.exist?(workspace)
      source_dir = workspace + '/SOURCES'

      resultdir = cmd.config[:resultdir] || workspace + '/SRPMS'
      if not File.exist?(resultdir)
        Dir.mkdir(resultdir)
      end

      if not File.exist?(resultdir)
        raise Exception.new("resultdir #{resultdir} does not exist.")
      end
      if repo
        begin
          repo_name = URI.parse(repo).path.split('/').last.gsub(/\.git$/,'')
        rescue Exception => e
          raise Exception.new('Invalid Git repo URL')
        end
        repo_dir = File.join(source_dir, repo_name)
        if not File.exist?(repo_dir)
          FileUtils.mkdir_p repo_dir
        end
        GitRPM.fetch(repo, repo_dir)
        pwd = Dir.pwd
        Dir.chdir repo_dir
        output = SRPM.create
        # FIXME
        # This is dangerous but SRPM.create does not return
        # the full filename
        pkg = Dir[output + '*.src.rpm'].first
        basename = File.basename(pkg)
        Dir.chdir pwd
        FileUtils.cp pkg, resultdir
        $stdout.puts "SRPM created: #{resultdir}/#{basename}"
      else
        output = SRPM.create
        # FIXME
        # This is dangerous but SRPM.create does not return
        # the full filename
        pkg = Dir[output + '*.src.rpm'].first
        basename = File.basename(pkg)
        FileUtils.cp pkg, resultdir
        $stdout.puts "SRPM created: #{resultdir}/#{basename}"
      end
    end

  end
end
