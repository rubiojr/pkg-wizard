module PKGWizard
  class Command
    include ::Mixlib::CLI

    option :help,
      :short => "-h",
      :long => "--help",
      :description => "Show this message",
      :on => :tail,
      :boolean => true,
      :show_options => true,
      :exit => 0 

    def self.registry
      @@registry ||= []
    end

    def run(argv)
      @@argv = argv
      cmd = argv.shift
      found = false
      @@registry.each do |c|
        if c[:name] == cmd
          c[:klass].perform
          found = true
        end
      end
      if not found
        puts
        puts "USAGE: #{File.basename($0)} command [options]"
        puts
        puts "Available Commands:"
        puts 
        @@registry.each do |c|
          puts c[:name]
        end
        puts 
      end
    end

  end
end
