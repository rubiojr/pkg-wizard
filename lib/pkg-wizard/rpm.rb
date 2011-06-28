require 'fileutils'
require 'pkg-wizard/streaming_downloader'
require 'uri'

module PKGWizard
  class NoSpecFound < Exception; end
  class RPMBuildError < Exception; end

  class RPM

    def initialize(pkg)
      @pkg = pkg.strip.chomp
      raise ArgumentError.new("Invalid package.") if pkg !~ /.*\.rpm$/
      raise ArgumentError.new("Invalid package.") if not File.exist?(pkg)
    end

    def source_package_name
      info = `rpm -qi -qp #{@pkg} 2>/dev/null`.lines
        info.find do |s|
        s =~ /^Source RPM\s*:(.*)$/
      end
      $1.strip.chomp
    end

  end

  class SpecFile
    attr_accessor :spec

    def self.parse(file)
      f = ''
      if File.exist?(file)
        f = File.read(file)
      else
        f = file
      end
      spec = SpecFile.new
      spec.spec = f
      spec
    end

    def files
      buf = []
      in_files = false
      @spec.each_line do |l|
        if l =~ /^\s*%files/
          in_files = true
          next
        end
        if l =~ /^\s*%(changelog|pre|pro|prep|preun|postun|post|install|clean|build|define)/ and in_files
          break
        end
        if in_files
          buf << l.strip.chomp if not l.strip.chomp.empty?
        end
      end
      buf
    end

    def release
      @spec.match(/Release:(.*?)$/i)[1].strip.chomp.gsub(/%\{\?.*\}/, '') rescue nil
    end

    def name
      @spec.match(/Name:(.*?)$/i)[1].strip.chomp rescue nil
    end

    def version
      @spec.match(/Version:(.*?)$/i)[1].strip.chomp rescue nil
    end

    def sources
      s = []
      @spec.each_line do |line|
        if line =~ /^\s*Source\d*:(.*)$/i
          s << $1.strip.chomp
        end
      end
      s
    end

    def build_requires
      build_requires = []
      @spec.each_line do |l|
        if l =~ /^\s*buildrequires:(.*)$/i
          build_requires = $1.split
          build_requires.reject! { |i| i !~ /^[a-zA-Z0-9]/ }
        end
      end
      build_requires
    end

    def requires
      requires = []
      @spec.each_line do |l|
        if l =~ /^\s*requires:(.*)$/i
          requires = $1.split
          requires.reject! { |i| i !~ /^[a-zA-Z0-9]/ }
        end
      end
      requires
    end

    def changelog
      buf = ""
      in_changelog = false
      @spec.each_line do |l|
        if l =~ /%changelog/
          in_changelog = true
          next
        end
        if in_changelog
          buf += l
        end
      end
      return buf
    end

    def changelog_entries
      entries = []
      cursor = -1
      changelog.each_line do |l|
        if l =~ /^\*/
          cursor += 1
          entries[cursor] = l
        else
          entries[cursor] += l if not l.strip.chomp.empty?
        end
      end
      entries
    end

    def download_source_files(defines = [], dest_dir = '.')
      define = ''
      if defines.is_a? Array and defines.size >= 1
        define = defines[0]
      elsif defines.is_a? String
        define = defines
      else
        define = nil
      end
      if define
        if define !~ /\w\s+\w/
          raise ArgumentError.new "Invalid --define syntax. Use 'macro_name macro_value'"
        else
          new_sources = []
          def_tokens = define.split
          sources.each do |s|
            new_sources << s.gsub(/%\{\??#{def_tokens[0]}\}/, def_tokens[1])
          end
        end
      else
        new_sources = sources
      end
      new_sources.each do |s|
        next if s !~ /http:\/\//
        yield s if block_given?
        download_from_url s, dest_dir
      end
    end
    
    def pkgname
      "#{name}-#{version}-#{release}"
    end
    
    private
    def download_from_url(url, tmpdir = '.')
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

  class SRPM
    #
    # params
    # rpmbuild_dir: _topdir macro
    # macros: macros string
    #
    def self.create(params = {})
      rpmbuild_dir = params[:rpmbuild_dir] || "#{ENV['HOME']}/rpmbuild/"
      macros = params[:macros] || ''
      rhel5_compat = params[:rhel5_compat] || false
      specs = Dir["*.spec"]
      raise NoSpecFound.new 'No spec found in current dir'  if specs.empty?
      pkg_name = File.read(specs.first).match(/Name:(.*?)$/)[1].strip.chomp
      pkg_ver = File.read(specs.first).match(/Version:(.*?)$/)[1].strip.chomp
      pkg_release = File.read(specs.first).match(/Release:(.*?)$/)[1].strip.chomp.gsub(/%\{\?.*\}/, '')
      pkg_full_name = "#{pkg_name}-#{pkg_ver}-#{pkg_release}"
      %w(SOURCES SRPMS SPECS BUILDROOT RPMS BUILD).each do |d|
        FileUtils.mkdir_p File.join(File.expand_path(rpmbuild_dir), d) if not File.exist?(File.join(rpmbuild_dir, d))
      end
      Dir['*'].each do |f|
        FileUtils.cp(f, "#{rpmbuild_dir}/SOURCES") if not File.directory?(f)
      end
      macros << " --define '_topdir #{rpmbuild_dir}'"
      if rhel5_compat
        macros << ' --define "_source_filedigest_algorithm 0" --define "_binary_filedigest_algorithm 0"'
      end
      output = `rpmbuild --nodeps -bs *.spec #{macros} 2>&1`
      resulting_pkg = ''
      output.each_line do |l|
        if l =~ /Wrote:/
          resulting_pkg = l.gsub('Wrote: ', '').strip.chomp
        end
      end
      raise RPMBuildError.new(output) if $? != 0
      resulting_pkg
    end
  end
end
