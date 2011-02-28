require 'git'

module PKGWizard

  class GitRPM
    def self.fetch(giturl, path, opts = {})
      # We pull if clone exists
      if File.directory?(path + '/.git')
        c = Git.open(path)
        c.pull
      else
        Git.clone giturl, path, opts
      end
    end
  end

end
