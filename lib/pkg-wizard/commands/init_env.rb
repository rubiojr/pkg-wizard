require 'pkg-wizard/command'
require 'pkg-wizard/rpm'
require 'pkg-wizard/logger'
require 'pkg-wizard/git'
require 'tmpdir'
require 'fileutils'
require 'uri'

module PKGWizard  
  class InitEnv < Command
    registry << { :name => 'init-env', :klass => self }

    option :help,
      :short => "-h",
      :long => "--help",
      :description => "Show this message",
      :on => :tail,
      :boolean => true,
      :show_options => true,
      :exit => 0
    
    def self.perform
      $stdout.sync = true
      cmd = InitEnv.new
      cmd.banner = "\nUsage: pkgwiz init-env\n\n"
      cmd.parse_options
      if `whoami`.strip.chomp != 'root'
        $stderr.puts 'Run this command as root.'
        exit 1
      end
      if File.exist?('/etc/redhat-release')
        puts '* Installing RHEL/Fedora requirements... '
        rhel_ver = File.readlines('/etc/redhat-release').first.match(/release\s+(\d+)/)[1] rescue nil
        if not rhel_ver
          $stderr.puts "Unsupported RHEL/Fedora distribution"
          exit 1
        end
        if rhel_ver == "6"
          puts "* Installing EPEL 6 repo.."
          abort_if_err "rpm -Uvh #{File.dirname(__FILE__)}/../../../packages/epel-release-6-5.noarch.rpm --force"
          puts "* Installing RBEL 6 repo.." 
          abort_if_err "rpm -Uvh #{File.dirname(__FILE__)}/../../../packages/rbel6-release-1.0-1.el6.noarch.rpm --force"
        elsif rhel_ver == "5"
          puts "* Installing EPEL 5 repo.."
          abort_if_err "rpm -Uvh #{File.dirname(__FILE__)}/../../../packages/epel-release-5-4.noarch.rpm --force"
          puts "* Installing RBEL 5 repo.." 
          abort_if_err "rpm -Uvh #{File.dirname(__FILE__)}/../../../packages/rbel5-release-1.0-1.el5.noarch.rpm --force"
        else
        end
        
        puts "* Installing init script..."
        FileUtils.cp File.dirname(__FILE__) + '/../../../resources/init-scripts/pkgwiz-buildbot', '/etc/init.d/'
        abort_if_err "chkconfig --add pkgwiz-buildbot"

        puts "* Installing dependencies..."
        abort_if_err "yum clean metadata"
        abort_if_err "yum install -y nodejs git rpm-build rpmdevtools mock createrepo yum-utils screen"
      elsif File.exist?('/etc/lsb-release') and \
        File.read('/etc/lsb-release') =~ /DISTRIB_ID=Ubuntu/
          puts '* Installing Ubuntu requirements... '
          abort_if_err "apt-get install -y nodejs git-core mock createrepo rpm yum screen"
      else
        $stderr.puts 'ERROR: Unsupported distribuition'
      end
      puts "* Done"
    end
    def self.abort_if_err(cmd, msg = nil)
      msg = "Failed running command: #{cmd}" if msg.nil?
      output = `#{cmd} 2>&1`
      if $? != 0
        $stderr.puts msg
        $stderr.puts output
        exit 1
      end
    end

  end
end
