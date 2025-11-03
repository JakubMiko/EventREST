GrapeSwaggerRails.options.url      = "/api/v1/swagger_doc"
GrapeSwaggerRails.options.app_name = "EventREST API"
GrapeSwaggerRails.options.app_url  = "/"

GrapeSwaggerRails.options.before_action do
  GrapeSwaggerRails.options.app_url = request.protocol + request.host_with_port
end

GrapeSwaggerRails.options.api_key_name = "Authorization"
GrapeSwaggerRails.options.api_key_type = "header"
GrapeSwaggerRails.options.api_key_placeholder = "Bearer YOUR_JWT_TOKEN"
GrapeSwaggerRails.options.api_key_default_value = ""