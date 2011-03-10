module PKGWizard
  module Utils
    def self.filesystem_status
      fs = {}
      `df -P`.each_line do |line|
        case line
        when /^Filesystem\s+1024-blocks/
          next
        when /^(.+?)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\%)\s+(.+)$/
          next if %{none tmpfs usbfs debugfs}.include? $1
          filesystem = $1
          fs[filesystem] = {}
          fs[filesystem][:kb_size] = $2
          fs[filesystem][:kb_used] = $3
          fs[filesystem][:kb_available] = $4
          fs[filesystem][:percent_used] = $5
          fs[filesystem][:mount] = $6
        end
      end
      fs
    end
  end
end
