# frozen_string_literal: true

class BaseSerializer
  include JSONAPI::Serializer

  def routes_helpers
    Rails.application.routes.url_helpers
  end
end
