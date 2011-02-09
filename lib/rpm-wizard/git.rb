require 'git'

module RPMWizard

  class GitRPM
    def self.fetch(giturl, path)
      # We pull if clone exists
      if File.directory?(path + '/.git')
        c = Git.open(path)
        c.pull
      else
        Git.clone giturl, path
      end
    end
  end

end
