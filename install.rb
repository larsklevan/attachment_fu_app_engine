initializer = File.dirname(__FILE__) + '/../../../config/initializers/app_engine_backend.rb'

unless File.exist? initializer
  initializer_template = IO.read(File.dirname(__FILE__) + '/initializer.rb.tpl')
  #File.open(initializer, 'w') { |f| f << ERB.new(initializer_template).result }
  File.open(initializer, 'w') { |f| f << 'blah' }
end

puts IO.read(File.join(File.dirname(__FILE__), 'README'))
