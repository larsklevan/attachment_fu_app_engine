import os
import cgi
from StringIO import StringIO
import struct

import wsgiref.handlers
from datetime import date

from google.appengine.api import images
from google.appengine.api import memcache
from google.appengine.ext import db
from google.appengine.ext import webapp
from google.appengine.ext.webapp import template

class Attachment(db.Model):
  path = db.StringProperty()

  filename = db.StringProperty()
  uploaded_data = db.BlobProperty()
  content_type = db.StringProperty()
  height = db.IntegerProperty()
  width = db.IntegerProperty()
  size = db.IntegerProperty()

  # FROM http://www.google.com/codesearch?hl=en&q=+getImageInfo+show:RjgT7H1iBVM:V39CptbrGJ8:XcXNaKeZR3k&sa=N&cd=2&ct=rc&cs_p=http://www.zope.org/Products/Zope3/3.0.0final/ZopeX3-3.0.0.tgz&cs_f=ZopeX3-3.0.0/Dependencies/zope.app.file-ZopeX3-3.0.0/zope.app.file/image.py#l88
  def extract_image_attributes(self,data):
    data = str(data)
    size = len(data)
    height = -1
    width = -1
    content_type = ''

    # handle GIFs
    if (size >= 10) and data[:6] in ('GIF87a', 'GIF89a'):
        # Check to see if content_type is correct
        content_type = 'image/gif'
        w, h = struct.unpack("<HH", data[6:10])
        width = int(w)
        height = int(h)

    # See PNG v1.2 spec (http://www.cdrom.com/pub/png/spec/)
    # Bytes 0-7 are below, 4-byte chunk length, then 'IHDR'
    # and finally the 4-byte width, height
    elif ((size >= 24) and data.startswith('\211PNG\r\n\032\n') and (data[12:16] == 'IHDR')):
        content_type = 'image/png'
        w, h = struct.unpack(">LL", data[16:24])
        width = int(w)
        height = int(h)

    # Maybe this is for an older PNG version.
    elif (size >= 16) and data.startswith('\211PNG\r\n\032\n'):
        # Check to see if we have the right content type
        content_type = 'image/png'
        w, h = struct.unpack(">LL", data[8:16])
        width = int(w)
        height = int(h)

    # handle JPEGs
    elif (size >= 2) and data.startswith('\377\330'):
        content_type = 'image/jpeg'
        jpeg = StringIO(data)
        jpeg.read(2)
        b = jpeg.read(1)
        try:
            while (b and ord(b) != 0xDA):
                while (ord(b) != 0xFF): b = jpeg.read(1)
                while (ord(b) == 0xFF): b = jpeg.read(1)
                if (ord(b) >= 0xC0 and ord(b) <= 0xC3):
                    jpeg.read(3)
                    h, w = struct.unpack(">HH", jpeg.read(4))
                    break
                else:
                    jpeg.read(int(struct.unpack(">H", jpeg.read(2))[0])-2)
                b = jpeg.read(1)
            width = int(w)
            height = int(h)
        except struct.error:
            pass
        except ValueError:
            pass

    return height,width

  def update_uploaded_data(self, data, content_type):
    if content_type.startswith('image'):
      self.height, self.width = self.extract_image_attributes(data)
      if not self.height:
        #if we can't determine the image attributes in the original format try converting it to a PNG with a no-op rotate
        image = images.Image(data)
        image.rotate(0)
        self.height, self.width = self.extract_image_attributes(image.execute_transforms(output_encoding=images.PNG))

    self.content_type = content_type
    self.uploaded_data = data
    self.size = len(data)
  
  # I'm attempting to replicate the resize format from http://www.imagemagick.org/Usage/resize/#resize
  # at least enough to be usable for avatar or photo gallery thumbnails
  def resize(self, format):
    preserve_aspect_ratio = True
    allow_scale_up = True
    if format.endswith("!"):
      preserve_aspect_ratio = False
      format = format.rstrip("!")
    elif format.endswith(">"):
      allow_scale_up = False
      format = format.rstrip(">")

    width,height = format.split('x')

    img = images.Image(self.uploaded_data)
    if not preserve_aspect_ratio:
      requested_aspect = float(height)/float(width)
      aspect = float(self.height)/float(self.width)

      ratio = requested_aspect / aspect
      if (ratio < 1):
        left_x = 0.0
        right_x = 1.0
        top_y = 0.5 - (ratio / 2)
        bottom_y = 0.5 + (ratio / 2)
      else:
        top_y = 0.0
        bottom_y = 1.0
        left_x = 0.5 - ((1/ratio) / 2)
        right_x = 0.5 + ((1/ratio) / 2)

      # seem to have issues with small rounding errors for larger images - request for 2000x2000 can end up at 1998x2000
      # presumably rounding errors - the 0-1 scale for cropping is weird...
      img.crop(left_x=left_x,top_y=top_y,right_x=right_x,bottom_y=bottom_y)

    if allow_scale_up or int(width) < self.width or int(height) < self.height:
      img.resize(width=int(width), height=int(height))

    output_encoding, content_type = images.PNG, 'image/png'
    if self.content_type == 'image/jpeg' or self.content_type == 'image/jpg':
      output_encoding, content_type = images.JPEG, 'image/jpeg'

    img.rotate(0) #no-op so that we don't break if we haven't done any transforms
    return img.execute_transforms(output_encoding), content_type

class UploadAttachmentPage(webapp.RequestHandler):
  def get(self):
    path = os.path.join(os.path.dirname(__file__), 'new.html')
    self.response.out.write(template.render(path, {}))

class AttachmentPage(webapp.RequestHandler):
  def get(self):
    attachment = None
    try:
      id = self.request.path.split('/')[-1]
      attachment = Attachment.get(db.Key(id))
    except:
      None

    if not attachment:
      attachment = db.Query(Attachment).filter("path =", self.request.path[1::]).get()

    if not attachment:
      # Either "id" wasn't provided, or there was no attachment with that ID
      # in the datastore.
      self.error(404)
      return

    today = date.today()
    self.response.headers.add_header("Expires", date(year=today.year + 1,month=today.month, day=today.day).ctime())
    format = self.request.get("resize")
    if format:
      memcache_client = memcache.Client()
      cache_key = "attachment-" + str(attachment.key()) + "-" + format
      result = memcache_client.get(cache_key)
      if not result:
        data, content_type = attachment.resize(format)
        memcache_client.set(cache_key, [data, content_type])
      else:
        data, content_type = result[0], result[1]
      self.response.headers['Content-Type'] = content_type
      self.response.out.write(data)
    else:
      self.response.headers['Content-Type'] = str(attachment.content_type)
      self.response.out.write(attachment.uploaded_data)

  def post(self):
    form = cgi.FieldStorage()
    
    path = form.getvalue('path')
    attachment = db.Query(Attachment).filter("path =", path).get()
    if not attachment:
      attachment = Attachment()
    attachment.path = path
    
    uploaded_data = form['uploaded_data']
    attachment.filename = uploaded_data.filename

    attachment.update_uploaded_data(uploaded_data.value, uploaded_data.type)
    attachment.put()

    self.redirect('/attachments/' + str(attachment.key()))
  
def main():
  application = webapp.WSGIApplication(
    [('/attachments/new', UploadAttachmentPage),
      ('/attachments.*', AttachmentPage)],
    debug=True)
  wsgiref.handlers.CGIHandler().run(application)

if __name__ == "__main__":
  main()
