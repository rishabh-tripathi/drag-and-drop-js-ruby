YOURAPP::Application.routes.draw do 
  match "/upload-assets/(:id)" => "upload#upload_assets", :as => :upload_assets
end
