# if you're using this in production I'd recommend creating your own app engine app with the provided backend code
Technoweenie::AttachmentFu::Backends::AppEngineBackend.base_url = "http://attachment-fu-gae.appspot.com"

# storage prefix prevents collission between multiple apps using the same app engine for storage
Technoweenie::AttachmentFu::Backends::AppEngineBackend.storage_prefix = "<%= require 'base64'; Base64.encode64(rand(10e15).to_s).strip %>"