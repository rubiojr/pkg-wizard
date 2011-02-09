module RPMWizard
  class NoSpecFound < Exception; end
  class RPMBuildError < Exception; end

  class RPM
  end

  class SpecFile
    attr_accessor :name, :release, :version

    def self.parse(file)
      f = File.read(file)
      spec = SpecFile.new
      spec.name = f.match(/Name:(.*?)$/)[1].strip.chomp
      spec.version = f.match(/Version:(.*?)$/)[1].strip.chomp
      spec.release = f.match(/Release:(.*?)$/)[1].strip.chomp.gsub(/%\{\?.*\}/, '')
      spec
    end

    def pkgname
      "#{name}-#{version}-#{release}"
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
        Dir.mkdir File.join(File.expand_path(rpmbuild_dir), d) if not File.exist?(File.join(rpmbuild_dir, d))
      end
      Dir['*'].each do |f|
        FileUtils.cp(f, "#{rpmbuild_dir}/SOURCES") if not File.directory?(f)
      end
      macros << " --define '_topdir #{rpmbuild_dir}'"
      if rhel5_compat
        macros << ' --define "_source_filedigest_algorithm 0" --define "_binary_filedigest_algorithm 0"'
      end
      output = `rpmbuild --nodeps -bs *.spec #{macros} 2>&1`
      raise RPMBuildError.new(output) if $? != 0
      "#{rpmbuild_dir}/SRPMS/#{pkg_full_name}"
    end
  end
end
