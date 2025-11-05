module EventRest
  module V1
    class Base < Grape::API
      class ApiException < StandardError
        attr_reader :status
        def initialize(message, status)
          super(message)
          @status = status.to_i
        end
      end

      rescue_from ApiException do |e|
        error!({ error: e.message }, e.status)
      end
      rescue_from Grape::Exceptions::ValidationErrors do |e|
        error!({ error: e.full_messages.join(", ") }, 422)
      end

      version "v1", using: :path

      get :ping do
        { ping: "pong", time: Time.now }
      end

      helpers do
        def current_user
          token = headers["Authorization"]&.split(" ")&.last
          payload = JWT.decode(token, Rails.application.credentials.secret_key_base)[0] rescue nil
          payload ? User.find_by(id: payload["user_id"]) : nil
        end

        def authorize!
          raise ApiException.new("Unauthorized", 401) unless current_user
        end

        def admin_only!
          authorize!
          raise ApiException.new("Forbidden", 403) unless current_user.admin?
        end
      end

      mount EventRest::V1::Users
      mount EventRest::V1::Events
      mount EventRest::V1::TicketBatches

      add_swagger_documentation(
        api_version: "v1",
        hide_documentation_path: true,
        mount_path: "/swagger_doc",
        hide_format: true,
        base_path: "/api",
        info: { title: "EventRest API", description: "API for event management" }
      )
    end
  end
end
