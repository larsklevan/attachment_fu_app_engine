Gem::Specification.new do |s|
  s.name     = "attachment_fu_app_engine"
  s.version  = "0.1.0"
  s.date     = "2008-07-26"
  s.summary  = "Extension for AttachmentFu which uses the Google App Engine for storage"
  s.email    = "tastybyte@gmail.com"
  s.homepage = "http://github.com/larsklevan/attachment_fu_app_engine"
  s.description = "Extension for AttachmentFu (http://github.com/technoweenie/attachment_fu) which uses the Google App Engine for storage and image resizing."
  s.has_rdoc = true
  s.authors  = ["Lars Klevan"]
  s.files    = %w{app_engine/attachment_fu_app_engine/app.yaml app_engine/attachment_fu_app_engine/attachment.py app_engine/attachment_fu_app_engine/index.yaml app_engine/attachment_fu_app_engine/new.html app_engine/attachment_fu_app_engine/photo.pyc attachment_fu_app_engine.gemspec init.rb initializer.rb.tpl install.rb lib/multipart_post.rb lib/tasks/migrate.rake lib/technoweenie/attachment_fu/backends/app_engine_backend.rb MIT-LICENSE Rakefile README}
end

