module EventRest
  class API < Grape::API
    prefix "api"
    format :json

    mount EventRest::V1::Base
  end
end
