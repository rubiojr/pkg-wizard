require 'rpm-wizard/command'
require 'rpm-wizard/rpm'
require 'rpm-wizard/logger'
require 'rpm-wizard/git'
require 'tmpdir'
require 'fileutils'

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

    option :tmpdir,
      :short => '-t DIR',
      :long => '--tmpdir DIR',
      :description => 'Git repo URL to fetch the package sources from'

    def self.perform
      cmd = CreateSrpm.new
      cmd.banner = "\nUsage: rpmwiz create-srpm (options)\n\n"
      cmd.parse_options
      repo = cmd.config[:gitrepo]
      tmpdir = cmd.config[:tmpdir] || "/tmp/rpmwiz-#{Time.now.to_i}"
      source_dir = tmpdir + '/SOURCES'
      srpm_dir = tmpdir + '/SRPMS'
      if not File.exist?(tmpdir)
        Dir.mkdir tmpdir
        Dir.mkdir srpm_dir
        Dir.mkdir source_dir
      end
      if repo
        GitRPM.fetch(repo, source_dir)
        pwd = Dir.pwd
        Dir.chdir source_dir
        output = SRPM.create
        # FIXME
        # This is dangerous but SRPM.create does not return
        # the full filename
        pkg = Dir[output + '*.src.rpm'].first
        puts pkg
        basename = File.basename(pkg)
        FileUtils.cp pkg, '../SRPMS/' + basename
        Dir.chdir pwd
        Logger.instance.info "SRPM created: #{tmpdir}/SRPMS/#{File.basename(pkg)}"
      else
        output = SRPM.create
        # FIXME
        # This is dangerous but SRPM.create does not return
        # the full filename
        pkg = Dir[output + '*.src.rpm'].first
        basename = File.basename(pkg)
        FileUtils.cp pkg, tmpdir + '/SRPMS/' + basename
        Logger.instance.info "SRPM created: #{tmpdir}/SRPMS/#{basename}"
      end
    end

  end
end
