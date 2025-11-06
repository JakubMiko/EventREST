module EventRest
  module V1
    class Events < Grape::API
      resource :events do
        desc "Get all events (with filters)" do
          success code: 200, message: "Returns a list of events"
        end
        params do
          optional :category, type: String
          optional :upcoming, type: Boolean
          optional :past, type: Boolean
        end
        get do
          events = EventsQuery.new(params: params).call
          EventSerializer.new(events).serializable_hash
        end

        desc "Get event details by id" do
          success code: 200, message: "Returns event details"
          failure code: 404, message: "Event not found"
        end
        params do
          requires :id, type: Integer
        end
        get ":id" do
          event = Event.includes(:ticket_batches).find_by(id: params[:id])
          raise EventRest::V1::Base::ApiException.new("Event not found", 404) unless event
          EventSerializer.new(event).serializable_hash
        end

        desc "Create event (admin only)" do
          success code: 201, message: "Event created"
          failure code: 422, message: "Validation failed"
        end
        params do
          requires :name, type: String
          requires :description, type: String
          requires :place, type: String
          requires :date, type: DateTime
          requires :category, type: String
          optional :image
        end
        post do
          admin_only!
          declared_params = declared(params, include_missing: false)
          result = ::Events::CreateService.new(declared_params).call
          raise EventRest::V1::Base::ApiException.new(result.failure, 422) if result.failure?
          status 201
          EventSerializer.new(result.value!).serializable_hash
        end

        desc "Update event (admin only)" do
          success code: 200, message: "Event updated"
          failure code: 404, message: "Event not found"
          failure code: 422, message: "Validation failed"
        end
        params do
          requires :id, type: Integer
          optional :name, type: String
          optional :description, type: String
          optional :place, type: String
          optional :date, type: DateTime
          optional :category, type: String
          optional :image
        end
        put ":id" do
          admin_only!
          event = Event.find_by(id: params[:id])
          raise EventRest::V1::Base::ApiException.new("Event not found", 404) unless event
          updates = declared(params, include_missing: false).except(:id)
          result = ::Events::UpdateService.new(event, updates).call
          raise EventRest::V1::Base::ApiException.new(result.failure, 422) if result.failure?
          EventSerializer.new(result.value!).serializable_hash
        end

        desc "Delete event (admin only)" do
          success code: 200, message: "Event deleted"
          failure code: 404, message: "Event not found"
        end
        params do
          requires :id, type: Integer
        end
        delete ":id" do
          admin_only!
          event = Event.find_by(id: params[:id])
          raise EventRest::V1::Base::ApiException.new("Event not found", 404) unless event
          event.destroy
          { message: "Event deleted" }
        end
      end
    end
  end
end
