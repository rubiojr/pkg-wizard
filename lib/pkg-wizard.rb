require 'rubygems'
require 'fileutils'
require 'mixlib/cli'

module PKGWizard

  VERSION = '0.1.8'
  
  class Distribution
    def self.detect
      if File.exist?('/etc/redhat-release') and \
        File.read('/etc/redhat-release') =~ /Fedora/
        return Fedora.new
      end
      if File.exist?('/etc/redhat-release') and \
        File.read('/etc/redhat-release') =~ /FrameOS|RedHat|CentOS/
        return RedHat.new
      end
      if `lsb_release -i` =~ /Ubuntu/
        return Ubuntu.new
      end
      return UnknownDistro.new
    end
  end

  class UnknownDistro
    def prepare_env
    end

    def to_s
      'unknown'
    end
  end

  class Ubuntu
    def prepare_env
    end
    def to_s
      'ubuntu'
    end
  end

  class RedHat
    def prepare_env
      if `uname -r` =~ /\.el6\./
      else
        raise UnsupportedDistribution.new('Unsupported RHEL distribution')
      end
      output = `yum install createrepo yum-utils rsync git rpmdevtools wget mock 2>&1`
    end
    def to_s
      'redhat'
    end
  end

  class Fedora
    def prepare_env
    end
    def to_s
      'fedora'
    end
  end

  class UnsupportedDistribution < Exception
  end

end
