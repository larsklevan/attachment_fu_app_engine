class MultipartPost
  # see http://www.realityforge.org/articles/2006/03/02/upload-a-file-via-post-with-net-http for file upload with http
  def self.post(uri, params=[])
    chunks = []    
    params.each do |param|
      param[:name]
      chunks << if param[:mime_type]
        "Content-Disposition: form-data; name=\"#{CGI::escape(param[:name])}\"; filename=\"#{param[:filename]}\"\r\n" +
               "Content-Transfer-Encoding: binary\r\n" +
               "Content-Type: #{param[:mime_type]}\r\n" +
               "\r\n#{param[:value]}\r\n"
      else
        "Content-Disposition: form-data; name=\"#{CGI::escape(param[:name])}\"\r\n" +
               "\r\n#{param[:value]}\r\n"
      end
    end
    boundary = "349832898984244898448024464570528145"
    post_body = ""
    chunks.each do |chunk|
      post_body << "--#{boundary}\r\n"
      post_body << chunk
    end
    post_body << "--#{boundary}--\r\n"
    
    uri = URI.parse(uri)
    Net::HTTP.new(uri.host, uri.port).start do |http|
      http.request_post(uri.path, post_body, "Content-type" => "multipart/form-data; boundary=" + boundary)
    end
  end
end
