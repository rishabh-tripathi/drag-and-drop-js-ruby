class UploadedFile
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :cid, type: String, default: nil  
  field :file_name, type: String
  field :file_path, type: String 
  field :deployed_s3_url, type: String 
  field :thumb_image, type: String
  field :height, type: Integer
  field :width, type: Integer
  field :file_type, type: Integer, default: 0  

  FILE_TYPE_IMAGE = 0
  FILE_TYPE_FONT = 10
  FILE_TYPE_JS = 20
  FILE_TYPE_CSS = 30
  FILE_TYPE_AUDIO = 40
  FILE_TYPE_VIDEO = 50

  FILE_TYPE_NAMES = {
    FILE_TYPE_IMAGE => "Image",
    FILE_TYPE_FONT => "Font",
    FILE_TYPE_JS => "Javascript",
    FILE_TYPE_CSS => "Stylesheet",
    FILE_TYPE_AUDIO => "Audio",
    FILE_TYPE_VIDEO => "Video"
  }

  FILE_TYPE_EXT = {
    FILE_TYPE_IMAGE => ['jpg', 'png', 'jpeg', 'bmp', 'gif', 'JPG', 'PNG', 'JPEG', 'svg', 'SVG'],
    FILE_TYPE_FONT => ['ttf'],
    FILE_TYPE_JS => ['js'],
    FILE_TYPE_CSS => ['css'],
    FILE_TYPE_AUDIO => ['mp3'],
    FILE_TYPE_VIDEO => ['mp4', 'mkv']
  }

  def self.save_file(user, theme, request=nil, params=nil, bit=nil, brand_circle_id=nil, asset_category_id = nil)
    if(params[:imgId].present?) 
      file = UploadedFile.where(id: params[:imgId]).first
    else
      file = UploadedFile.new   
    end
    (file_path, file_name, thumb, file_type) = upload_file(request, params, user, theme, bit, brand_circle_id)
    file.file_name = file_name
    file.file_path = file_path
    file.thumb_image = thumb
    file.file_type = file_type
    file.save
    return file
  end
  
  def self.update_image_dimensions
    UploadedFile.all.each do |img|
      next if img.width.present?
      begin
        image = MiniMagick::Image.open(img.file_path)
        img.width = image[:width]
        img.height = image[:height]
        img.save
      rescue Exception => e              
      end
    end  
  end  

  # function called from uploader action location should be like "images/user_data"
  def self.upload_file(request = nil, params = nil, user = nil, theme = nil, bit = nil, brand_circle_id)
    status = true
    file_path = nil
    file_name = nil
    thumb = ""
    f_name = ""
    theme_id = (theme.blank?)? ((!bit.nil?)? "widget-assets" : "lmw-assets") : theme.id
    begin
      (f_name, file_name, file_type_str, file_type) = UploadedFile.get_file_info(request, params)      
      if((file_type == FILE_TYPE_FONT) || (theme_id == "lmw-assets")) 
        new_file_name = file_name+"."+file_type_str
        thumb = "/assets/" + file_type_str + ".png"
      else
        encrypted_file_name = Util.random_alphanumeric(20)
        new_file_name = encrypted_file_name+"."+file_type_str
      end
      file_path = UploadedFile.save_to_s3(new_file_name, params, request, brand_circle_id, theme_id)      
    rescue Exception => e       
      status = false
    end
    if(status)
      # convert and save thumb of image here and push its url to thumb
    end
    return [file_path, file_name, thumb, file_type]
  end

  # This method clone uploaded file to one folder to another
  def self.clone_uploaded_file(theme, user_id, old_file_path)
    path = "#{Rails.root}/public/AppAssets/#{user_id}/#{theme.id}/"
    FileUtils.mkdir_p(path)
    encrypted_file_name = Util.random_alphanumeric(20)
    file_type_str = old_file_path.split(".").last
    new_file_name = "#{encrypted_file_name}.#{file_type_str}"
    file_path = "/AppAssets/#{user_id}/#{theme.id}/#{new_file_name}"
    if(File.exist?("#{Rails.root}/public#{old_file_path}"))
      FileUtils.cp("#{Rails.root}/public#{old_file_path}", "#{Rails.root}/public#{file_path}")
    end    
    return file_path
  end
  
  # this method copy theme assets file to newly created app
  def self.copy_uploaded_files(theme, app_path)
    all_files = UploadedFile.where(theme_id: theme.id)
    if(!all_files.blank?)
      # files_path = app_path + "app/assets/images/#{theme.owner_id}/#{theme.id}/"
      files_path = app_path + "public/AppAssets/"
      FileUtils.mkdir_p(files_path)
      for file in all_files
        if(File.exist?("#{Rails.root}/public#{file.file_path}"))
          FileUtils.cp("#{Rails.root}/public#{file.file_path}", files_path)
        end
      end
    end
  end
    
  def self.get_file_type(file_type_str)
    file_type = nil
    FILE_TYPE_EXT.each do |key, cat|
      if cat.include? file_type_str.downcase
        file_type = key
        break;
      end
    end
    return file_type
  end

  # file info from request and params
  def self.get_file_info(request, params)
    if(!request.nil?)
      f_name = request.env['HTTP_X_FILE_NAME']
    else
      f_name = params.original_filename
    end    
    f_name = f_name.tr(" ","_")
    file_name = f_name.gsub(".#{f_name.split('.').last}","")
    file_name = file_name.tr(".","_")
    file_name = file_name.tr(" ","_")
    file_type_str = f_name.split('.').last
    file_type = get_file_type(file_type_str)
    return [f_name, file_name, file_type_str, file_type]
  end

  # Util methods
  # drag n drop save to disk
  def self.save_to_disk(file_loc, params, request)   
    params = nil #make the params as default as nil
    pic = File.new(file_loc, "wb")
    if(params.nil? || params.empty?)
      pic.write Base64.decode64(request.body.read) # .gsub(/^(data:)[\w\W]+(;base64,)/,"")
    else
      pic.write params.read
    end
    pic.close
  end

  # save to s3
  def self.save_to_s3(new_file_name, params, request, brand_circle_id, theme_id)   
    params = nil #make the params as default as nil
    service = AWS::S3.new(:access_key_id => ACCESS_KEY_ID,
                          :secret_access_key => SECRET_ACCESS_KEY)
    bucket_name = "bucketname"
    s3_buckets = service.buckets
    if(s3_buckets.entries.collect(&:name).include?(bucket_name))
      bucket = s3_buckets[bucket_name]
    else
      bucket = service.buckets.create(bucket_name)
    end
    bucket.acl = :public_read
    new_file_name = theme_id.to_s + "/" + new_file_name
    new_object = bucket.objects[new_file_name]
    if(params.nil? || params.empty?)
      new_object.write(Base64.decode64(request.body.read), :cache_control => "public, max-age=2592000")
    else
      new_object.write(params.read, :cache_control => "public, max-age=2592000") 
    end
    new_object.acl = :public_read
    return "http://s3-ap-southeast-1.amazonaws.com/" + bucket_name + "/" + new_file_name
  end
  
  def self.delete_from_s3(file, brand_circle_id) 
    service = AWS::S3.new(:access_key_id => ACCESS_KEY_ID,
                          :secret_access_key => SECRET_ACCESS_KEY)
    bucket_name = "bucketname"
    if(service.buckets.include?(bucket_name))
      bucket = service.buckets[bucket_name]
    else
      bucket = service.buckets.create(bucket_name)
    end
    bucket.acl = :public_read
    file_name = file.file_path.split('/').last
    puts file_name
    new_object = bucket.objects[file_name]
    new_object.delete()
  end

  def self.optimize_image_quality(src, quality)
    # https://github.com/jtescher/image_optimizer
    ImageOptimizer.new(src, quality: quality).optimize
    # convert -strip -interlace Plane -gaussian-blur 0.05 -quality 85% source.jpg result.jpg
  end
  
  def self.optimize_s3_image(path, bucket_name, file_path, quality, new_dim = [], admin) 
    require "open-uri"    
    bkp_bucket_name = "bucketname"
    ext = path.split(".").last
    open(path) {|f|
      File.open("temp-img.#{ext}","wb") do |file|
        file.puts f.read
      end
    }
    if(new_dim.present? && (new_dim.size > 0))
      # Resize before optimizing image
      `convert temp-img.#{ext} -resize #{new_dim[0]}X#{new_dim[1]} temp-img.#{ext}`
      # `convert #{screenshot_original_location} -resize 650X500 -quality 94 #{screenshot_image_location}`
    end
    `convert temp-img.#{ext} -quality #{quality} temp-img.#{ext}`
    # Uploading optimize image
    service = AWS::S3.new(:access_key_id => ACCESS_KEY_ID,
                          :secret_access_key => SECRET_ACCESS_KEY)
    s3_buckets = service.buckets
    original_image = service.buckets[bucket_name].objects[file_path].copy_to(file_path, :bucket_name => bkp_bucket_name)
    original_image.acl = :public_read
    bkp_s3_path = original_image.public_url
    s3_file = service.buckets[bucket_name].objects[file_path].write(:file => "#{Rails.root}/temp-img.#{ext}", :cache_control => 'max-age=31536000', :expires => (DateTime.now + 365).httpdate)
    s3_file.acl = :public_read
    s3_path = s3_file.public_url
  end
    
end
