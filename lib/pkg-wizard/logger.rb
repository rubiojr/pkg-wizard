require 'logger'
require 'delegate'
require 'singleton'

module PKGWizard
  OriginalLogger = Logger
  class Logger < SimpleDelegator
    include Singleton

    def initialize
      @logger = OriginalLogger.new(STDOUT)
      super @logger
    end
  end

  def set_output(log_device)
    @logger = OriginalLogger.new(log_device)
    __setobj__(@logger)
  end  

end
