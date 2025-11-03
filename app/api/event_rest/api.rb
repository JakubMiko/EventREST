module EventREST
  class API < Grape::API
    prefix "api"
    format :json

    mount EventREST::V1::Base
  end
end
