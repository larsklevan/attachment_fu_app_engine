# move from s3 to gae

desc 'Migrate file data from s3 storage to app engine'
task :migrate_s3_to_app_engine => :environment do
  require 'open-uri'
  require 'multipart_post'

  raise 'You should specify the class to migrate with ATTACHMENT_CLASS=Image'
  clazz = ENV['ATTACHMENT_CLASS'].constantize

  raise 'You should set the :storage option from your class to :s3 when you run this migration' unless clazz.attachment_options[:storage].to_s == 's3'

  app_engine_config = Technoweenie::AttachmentFu::Backends::AppEngineBackend

  failures = []
  clazz.find(:all).each do |o|
    next if o.respond_to?(:parent) && o.parent
    begin
      puts "Migrating #{o.public_filename}"
  
      temp_data = open(o.public_filename).read

      app_engine_path = ['attachments', app_engine_config.storage_prefix, clazz.attachment_options[:path_prefix], o.id, o.filename].compact.join('/')

      response = MultipartPost.post(app_engine_config.base_url + '/attachments', [
        {:name => 'uploaded_data', :filename => o.filename, :mime_type => o.content_type, :value => temp_data},
        {:name => 'path', :value => app_engine_path}
      ])
      raise response.body unless response.is_a? Net::HTTPRedirection
    rescue => err
      puts "Failed to migrate #{o.public_filename} - #{err.message}"
      failures << o.id
      next
    end
  end
  puts "#{failures.size} files failed to migrate" unless failures.empty?
end
