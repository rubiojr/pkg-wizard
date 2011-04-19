require 'pkg-wizard/command'
require 'pkg-wizard/rpm'
require 'tmpdir'
require 'fileutils'
require 'pkg-wizard/streaming_downloader'
require 'uri'

module PKGWizard  
  class DownloadSources < Command
    registry << { :name => 'download-sources', :klass => self }

    option :help,
      :short => "-h",
      :long => "--help",
      :description => "Show this message",
      :on => :tail,
      :boolean => true,
      :show_options => true,
      :exit => 0
    
    option :define,
      :short => '-d MACRO',
      :long => '--define MACRO',
      :description => 'Define macro that will be replaced in the sources'
    
    option :spec,
      :short => '-s SPEC',
      :long => '--spec SPEC',
      :description => 'Spec file where the sources are declared'

    def self.perform
      cmd = DownloadSources.new
      cmd.banner = "\nUsage: pkgwiz download-sources (options)\n\n"
      cmd.parse_options

      spec = nil
      if cmd.config[:spec]
        spec = PKGWizard::SpecFile.parse cmd.config[:spec]
      else
        files = Dir["*.spec"]
        if files.size > 1 
          $stderr.puts 'Multiple spec files found in current dir. Use --spec option.'
          exit 1
        elsif files.empty?
          $stderr.puts 'No spec files found in current dir. Use --spec option.'
          exit 1
        else
          spec = PKGWizard::SpecFile.parse files[0]
        end
      end
      define = cmd.config[:define]
      spec.download_source_files(define) do |s|
        puts "Downloading #{s}..."
      end
    end
    
    def self.download_from_url(url, tmpdir = '.')
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
