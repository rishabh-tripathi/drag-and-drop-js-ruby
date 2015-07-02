class UploadsController < ApplicationController
  def upload_assets
    img = UploadedFile.save_file(current_user, theme, request, params, nil, brand_circle_id, asset_category_id)
    render(:text => img.id)
  end
end
