module PKGWizard

  #
  # StreamingDownloader code based on HTTPDownloader
  # code from http://www.vagrantup.com
  #
  class StreamingDownloader
    def self.match?(uri)
      # URI.parse barfs on '<drive letter>:\\files \on\ windows'
      extracted = URI.extract(uri).first
      extracted && extracted.include?(uri)
    end

    def report_progress(progress, total, show_parts=true)
      line_reset = "\r\e[0K" 
      percent = (progress.to_f / total.to_f) * 100
      line = "Progress: #{percent.to_i}%"
      line << " (#{progress} / #{total})" if show_parts
      line = "#{line_reset}#{line}"
      $stdout.sync = true
      $stdout.print line
    end

    def download!(source_url, destination_file)
      proxy_uri = URI.parse(ENV["http_proxy"] || "")
      uri = URI.parse(source_url)
      http = Net::HTTP.new(uri.host, uri.port, proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)

      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      http.start do |h|
        h.request_get(uri.request_uri) do |response|
          total = response.content_length
          progress = 0
          segment_count = 0

          response.read_body do |segment|
            # Report the progress out
            progress += segment.length
            segment_count += 1

            # Progress reporting is limited to every 25 segments just so
            # we're not constantly updating
            if segment_count % 25 == 0
              report_progress(progress, total)
              segment_count = 0
            end


            # Store the segment
            destination_file.write(segment)
          end
        end
    end
    rescue SocketError
      raise Errors::DownloaderHTTPSocketError.new
    end
  end
end
