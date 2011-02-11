require 'rpm-wizard/command'
require 'rpm-wizard/rpm'
require 'rpm-wizard/logger'
require 'rpm-wizard/git'
require 'rpm-wizard/mock'
require 'tmpdir'
require 'fileutils'
require 'uri'
require 'sinatra/base'
require 'rufus/scheduler'
require 'pp'

module RPMWizard  
  class BuildBot < Command
    registry << { :name => 'build-bot', :klass => self }

    option :help,
      :short => "-h",
      :long => "--help",
      :description => "Show this message",
      :on => :tail,
      :boolean => true,
      :show_options => true,
      :exit => 0

    option :resultdir,
      :short => '-r DIR',
      :long => '--resultdir DIR',
      :default => 'output'
    
    class Webapp < Sinatra::Base
      post '/build/' do
        pkg = params[:pkg]
        if pkg.nil?
          Logger.instance.error '400: Invalid arguments. Needs pkg in post request'
          status 400
          "Missing pkg parameter.\n"
        else
          incoming_file = "incoming/#{pkg[:filename]}"
          Logger.instance.info "Incoming file #{pkg[:filename]}"
          FileUtils.cp pkg[:tempfile].path, incoming_file
          Logger.instance.info "File #{pkg[:filename]} saved."
        end
      end

    end
    
    def self.perform
      Dir.mkdir 'incoming' if not File.exist?('incoming')
      Dir.mkdir 'output' if not File.exist?('output')
      Dir.mkdir 'workspace' if not File.exist?('workspace')
      scheduler = Rufus::Scheduler.start_new
      scheduler.every '2s', :blocking => true do
        queue = Dir['incoming/*.src.rpm'].sort_by {|filename| File.mtime(filename) }
        if not queue.empty?
          job_dir = "workspace/job_#{Time.now.strftime '%Y%m%d_%H%M%S'}"
          result_dir = job_dir + '/result'
          FileUtils.mkdir_p result_dir
          qfile = File.join(job_dir, File.basename(queue.first))
          FileUtils.mv queue.first, qfile
          Logger.instance.info "Building pkg #{qfile}"
          RPMWizard::Mock.srpm :srpm => qfile, :profile => 'abiquo-1.7', :resultdir => result_dir
          FileUtils.mv job_dir, 'output/'
          Logger.instance.info "Finished building #{qfile}"
        end
      end
      Webapp.run!
    end

  end
end
