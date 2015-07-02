class Util    
  def self.random_alphanumeric(size = 6)
    s = ""
    size.times { s << (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }
    return s
  end
  
  # pass the object and update the timestamps for the clone.
  def self.update_timestamp(mod_obj)
    mod_obj.update_attributes(updated_at: Time.now, created_at: Time.now)
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

  def self.update_file_content(file_path, temp_string, new_string)
    begin
      f_read = File.open(file_path, "r+") 
      content = f_read.read    
      content = content.gsub(temp_string, new_string) if !new_string.empty?      
      f_read.close
      f_write = File.open(file_path, "w+")
      f_write.write(content)
      f_write.close
      true
    rescue => ex
      false
    end    
  end
end
