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

        def public_filename(thumbnail = nil)
          thumbnails = HashWithIndifferentAccess.new(attachment_options[:thumbnails])

          query = if thumbnail && thumbnails[thumbnail]
            "?resize=#{thumbnails[thumbnail]}"
          elsif thumbnail.is_a?(String)
            "?resize=#{thumbnail}"
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
          uri = URI.parse(AppEngineBackend.base_url)
          Net::HTTP.new(uri.host, uri.port).start do |http|
            http.get(filename).response_body
          end
        end

        #TODO: HACK??
        def process_attachment
          @saved_attachment = true
        end

        # The full path to the file relative to the bucket name
        # Example: <tt>:table_name/:id/:filename</tt>
        def full_filename
          ['attachments', storage_prefix, attachment_options[:path_prefix].gsub('public/', ''), id.to_s, filename].compact.join('/')
        end

        def create_or_update_thumbnail(*args)
          #ignore
        end
        protected
          def destroy_file
            #ignore
          end

          def save_to_storage
            if save_attachment?
              response = MultipartPost.post(AppEngineBackend.base_url + '/attachments', [
                {:name => 'uploaded_data', :value => temp_data, :mime_type => content_type, :filename => filename},
                {:name => 'path', :value => full_filename}
              ])
              raise response.body unless response.is_a? Net::HTTPRedirection
            end
            true
          end
      end
    end
  end
end