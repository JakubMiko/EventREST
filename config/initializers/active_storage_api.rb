Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.skip_before_action :verify_authenticity_token, raise: false
end
