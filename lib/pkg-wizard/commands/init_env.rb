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
      cmd.banner = "\nUsage: rpmwiz init-env\n\n"
      cmd.parse_options
      if `whoami`.strip.chomp != 'root'
        $stderr.puts 'Run this command as root.'
        exit 1
      end
      if File.exist?('/etc/redhat-release')
        print '* Installing RHEL/Fedora requirements... '
        output = `yum install -y git rpmdevtools mock createrepo yum-utils`
        if $? != 0
          $stderr.puts "Failed installing requirementes: \n#{output}"
          exit 1
        end
        puts "done."
      elsif File.exist?('/etc/lsb-release') and \
        File.read('/etc/lsb-release') =~ /DISTRIB_ID=Ubuntu/
          print '* Installing Ubuntu requirements... '
          output = `apt-get install -y git-core mock createrepo rpm yum`
          if $? != 0
            $stderr.puts "Failed installing requirementes: \n#{output}"
            exit 1
          end
          puts "done."
      else
        $stderr.puts 'unsupported distribuition'
      end
    end

  end
end
