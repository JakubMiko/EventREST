module EventRest
  class API < Grape::API
    prefix "api"
    format :json
    default_format :json
    content_type :json, "application/json"

    error_formatter :json, ->(message, *_args) {
      (message.is_a?(String) ? { error: message } : message).to_json
    }

    mount EventRest::V1::Base
  end
end
