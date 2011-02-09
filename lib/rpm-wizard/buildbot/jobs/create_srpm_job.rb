require 'rubygems'
require 'resque'
require 'git'
require 'logger'

class CreateSRPM
  @queue = :srpm_builder

  @log = Logger.new($stdout)

  def self.perform(giturl, path, params = {})
    # We pull if clone exists
    if File.directory?(path + '/.git')
      @log.info 'pulling from origin'
      c = Git.open(path)
      c.pull
    else
      @log.info 'cloning repo'
      Git.clone giturl, path
    end
    pwd = Dir.pwd
    Dir.chdir path
    @log.info 'building SRPM'
    `orpium-create-srpm`
    Dir.chdir pwd
  end
end

CreateSRPM.perform 'git://github.com/abiquo-rpms/abiquo-am.git', '/tmp/clone'
