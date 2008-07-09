require 'net/http'
module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # store in Google App Engine
      module AppEngineBackend
        mattr_accessor :domain
        @@domain = "http://attachment-fu-gae.appspot.com"
        
        def self.included(base) #:nodoc:
          
        end
        def public_filename(thumbnail = nil)
          query = if thumbnail && attachment_options[:thumbnails] && attachment_options[:thumbnails][thumbnail]
            "?resize=#{attachment_options[:thumbnails][thumbnail]}"
          elsif attachment_options[:resize]
            "?resize=#{attachment_options[:resize]}"
          else
            ''
          end
          "#{AppEngineBackend.domain}/#{full_filename}#{query}"
        end

        def create_temp_file
          write_to_temp_file current_data
        end

        # Gets the current data from the database
        def current_data
          with_app_engine_connection do |http|
            http.get(filename).response_body
          end
        end

        #TODO: HACK??        
        def process_attachment
          @saved_attachment = true
        end
        
        # The pseudo hierarchy containing the file relative to the bucket name
        # Example: <tt>:table_name/:id</tt>
        def base_path
          ['attachments', attachment_options[:path_prefix].gsub('public/', ''), id.to_s].compact.join('/')
        end

        # The full path to the file relative to the bucket name
        # Example: <tt>:table_name/:id/:filename</tt>
        def full_filename
          [base_path, filename].join('/')
        end
        
        def create_or_update_thumbnail(*args)
          #ignore
        end
        protected
          # Destroys the file.  Called in the after_destroy callback
          def destroy_file

          end
          
          def with_app_engine_connection
            uri = URI.parse(AppEngineBackend.domain)
            Net::HTTP.new(uri.host, uri.port).start do |http|
              yield http
            end
          end

          def save_to_storage
            if save_attachment?
              # see http://www.realityforge.org/articles/2006/03/02/upload-a-file-via-post-with-net-http for file upload with http
              param = 'uploaded_data'
              filename = self.filename
              mime_type = content_type
              content = temp_data
              chunks = []
              chunks << "Content-Disposition: form-data; name=\"#{CGI::escape(param)}\"; filename=\"#{filename}\"\r\n" +
                     "Content-Transfer-Encoding: binary\r\n" +
                     "Content-Type: #{mime_type}\r\n\r\n" +
                     "#{content}\r\n"

              chunks << "Content-Disposition: form-data; name=\"path\"\r\n\r\n#{full_filename}\r\n"

              boundary = "349832898984244898448024464570528145"
              post_body = ""
              post_body << "--#{boundary}\r\n"
              chunks.each do |chunk|
                post_body << "--#{boundary}\r\n"
                post_body << chunk
              end
              post_body << "--#{boundary}--\r\n"

              response = with_app_engine_connection do |http|
                http.request_post('/attachments', post_body, "Content-type" => "multipart/form-data; boundary=" + boundary)
              end
              raise response.body unless response.is_a? Net::HTTPRedirection
            end
            true
          end
      end
    end
  end
end