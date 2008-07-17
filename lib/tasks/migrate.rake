# move from s3 to gae

desc 'Migrate file data from s3 storage to app engine'
task :migrate_s3_to_app_engine => :environment do
  require 'open-uri'

  clazz = Image

  raise 'You should set the :storage option to :s3 when you run this migration' unless clazz.attachment_options[:storage] == 's3'

  app_engine_config = Technoweenie::AttachmentFu::Backends::AppEngineBackend

  clazz.find(:all).each do |o|
    next if o.respond_to?(:parent) && o.parent

    temp_data = open(o.public_filename).read
  
    full_filename = ['attachments', app_engine_config.storage_prefix, clazz.attachment_options[:path_prefix], o.filename].compact.join('/')
  
    param = 'uploaded_data'
    filename = o.filename
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

    uri = URI.parse(app_engine_config.base_url)
    response = Net::HTTP.new(uri.host, uri.port).start do |http|
      http.request_post('/attachments', post_body, "Content-type" => "multipart/form-data; boundary=" + boundary)
    end
    raise response.body unless response.is_a? Net::HTTPRedirection
  end
end

#clazz.attachment_options[:storage] = :s3
# 
# require 'aws/s3'
# include AWS::S3
# 
# s3_config_path = clazz.attachment_options[:s3_config_path] || (RAILS_ROOT + '/config/amazon_s3.yml')
# s3_config = YAML.load(ERB.new(File.read(s3_config_path)).result)[RAILS_ENV].symbolize_keys
# 
# bucket_name = s3_config[:bucket_name]
# s3_config[:persistent] ||= false
# s3_config[:access_key_id] ||= ENV['AMAZON_ACCESS_KEY_ID']
# s3_config[:secret_access_key] ||= ENV['AMAZON_SECRET_ACCESS_KEY']
# 
# AWS::S3::Base.establish_connection!(s3_config.slice(:access_key_id, :secret_access_key, :server, :port, :use_ssl, :persistent, :proxy))
# 
# 
# path = File.join(clazz.attachment_options[:path_prefix], o.id, o.filename)
# 
# AWS::S3::S3Object.value '', bucket_name
