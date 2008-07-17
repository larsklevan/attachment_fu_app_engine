require 'net/http'
require 'multipart_post'

module Technoweenie # :nodoc:
  module AttachmentFu # :nodoc:
    module Backends
      # store in Google App Engine
      module AppEngineBackend
        mattr_accessor :base_url, :storage_prefix
        @@base_url = "http://attachment-fu-gae.appspot.com"
        @@storage_prefix = nil

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
          "#{AppEngineBackend.base_url}/#{full_filename}#{query}"
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
          ['attachments', storage_prefix, attachment_options[:path_prefix].gsub('public/', ''), id.to_s].compact.join('/')
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
          def destroy_file
            #ignore
          end

          def with_app_engine_connection
            uri = URI.parse(AppEngineBackend.base_url)
            Net::HTTP.new(uri.host, uri.port).start do |http|
              yield http
            end
          end

          def save_to_storage
            if save_attachment?
              response = with_app_engine_connection do |http|
                MultipartPost.post(http, [
                  {:name => 'uploaded_data', :value => temp_data, :mime_type => content_type, :filename => filename},
                  {:name => 'path', :value => full_filename}
                ])
              end
              raise response.body unless response.is_a? Net::HTTPRedirection
            end
            true
          end
      end
    end
  end
end