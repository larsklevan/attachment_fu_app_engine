require 'net/http'
module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # store in Google App Engine
      module GoogleAppEngineBackend
        mattr_accessor :app_engine_domain
        @@app_engine_domain = "attachment-fu-gae.appspot.com"
        
        def self.included(base) #:nodoc:
          
        end
        def public_filename(thumbnail = nil)
          query = thumbnail.nil? ? "" : "?resize=#{attachment_options[:thumbnails][thumbnail]}"
          "http://#{GoogleAppEngineBackend.app_engine_domain}/#{filename}#{query}"
        end

        def create_temp_file
          write_to_temp_file current_data
        end

        # Gets the current data from the database
        def current_data
          Net::HTTP.new(GoogleAppEngineBackend.app_engine_domain, 80).start do |http|
            http.get(filename).response_body
          end
        end

        #TODO: HACK??        
        def process_attachment
          @saved_attachment = true
        end

        protected
          # Destroys the file.  Called in the after_destroy callback
          def destroy_file

          end

          def save_to_storage
            if save_attachment?
              # see http://www.realityforge.org/articles/2006/03/02/upload-a-file-via-post-with-net-http for file upload with http
              param = 'uploaded_data'
              filename = self.filename
              mime_type = content_type
              content = temp_data
              chunk = "Content-Disposition: form-data; name=\"#{CGI::escape(param)}\"; filename=\"#{filename}\"\r\n" +
                     "Content-Transfer-Encoding: binary\r\n" +
                     "Content-Type: #{mime_type}\r\n" + 
                     "\r\n" + 
                     "#{content}\r\n"

              boundary = "349832898984244898448024464570528145"

              encoded_data = "--#{boundary}\r\n#{chunk}--#{boundary}--\r\n"
              response = Net::HTTP.new(GoogleAppEngineBackend.app_engine_domain, 80).start do |http|
                http.request_post('/photos', encoded_data, "Content-type" => "multipart/form-data; boundary=" + boundary)
              end
              location = response['Location'].split('/')
              location.slice!(0,3)

              self.class.update_all("filename = '#{location.join('/')}'", :id => id)
            end
            true
          end
      end
    end
  end
end