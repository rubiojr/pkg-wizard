module RPMWizard 
  class Mock

    #
    # mandatory args 
    #   :profile
    #   :resultdir
    #   :srpm
    #
    def self.srpm(args =  {})
      mock_profile = args[:profile]
      result_dir = args[:resultdir]
      srpm = args[:srpm]
      mock_args = args[:mock_args] || ""

      raise ArgumentError.new('Invalid mock profile') if mock_profile.nil?

      if not File.exist?(srpm) or (srpm !~ /src\.rpm$/)
        raise ArgumentError.new('Invalid SRPM')
      end

      raise ArgumentError.new('Invalid result dir') if result_dir.nil?


      if mock_profile.nil?
        raise Exception.new "Missing mock profile."
      end
      
      if result_dir.nil?
        raise Exception.new "Missing result_dir."
      end

      if not File.directory?(result_dir)
        raise Exception.new "Invalid result_dir #{result_dir}"
      end

      cmd = "/usr/bin/mock #{mock_args} -r #{mock_profile} --disable-plugin ccache --resultdir #{result_dir} #{srpm}"
      output = `#{cmd} 2>&1`
      if $? != 0
        raise Exception.new(output)
      end
      output
    end
  end # class
end # mod
