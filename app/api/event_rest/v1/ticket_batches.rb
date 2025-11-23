# frozen_string_literal: true

module EventRest
  module V1
    class TicketBatches < Grape::API
      resource :events do
        route_param :event_id, type: Integer do
          desc "Ticket batches for event (state + order)" do
            success code: 200, message: "Returns ticket batches for the event"
            failure [ { code: 404, message: "Event not found" } ]
          end
          params do
            optional :state, type: String, values: %w[available sold_out expired inactive all], default: "all"
            optional :order, type: String, values: %w[asc desc], default: "asc"
          end
          get :ticket_batches do
            event = Event.find(params[:event_id])

            collection = TicketBatchQuery.new(
              relation: event.ticket_batches,
              state: params[:state],
              order: params[:order]
            ).call

            TicketBatchSerializer.new(collection, include: [ :event ]).serializable_hash
          end

          desc "Create ticket batch (admin only)" do
            success code: 201, message: "Ticket batch created"
            failure [ { code: 401, message: "Unauthorized" },
                     { code: 403, message: "Forbidden" },
                     { code: 404, message: "Event not found" },
                     { code: 422, message: "Validation failed" } ]
          end
          params do
            requires :available_tickets, type: Integer
            requires :price, type: BigDecimal
            requires :sale_start, type: DateTime
            requires :sale_end, type: DateTime
          end
          post :ticket_batches do
            admin_only!
            event = Event.find(params[:event_id])
            declared_params = declared(params, include_missing: false)
            result = ::TicketBatches::CreateService.new(event: event, params: declared_params).call
            raise EventRest::V1::Base::ApiException.new(result.failure, 422) unless result.success?
            status 201
            TicketBatchSerializer.new(result.value!).serializable_hash
          end
        end
      end

      resource :ticket_batches do
        desc "Show ticket batch" do
          success code: 200, message: "Returns ticket batch details"
          failure [ { code: 404, message: "Ticket batch not found" } ]
        end
        params do
          requires :id, type: Integer
        end
        get ":id" do
          batch = ::TicketBatch.includes(:event).find(params[:id])
          TicketBatchSerializer.new(batch, include: [ :event ]).serializable_hash
        end

        desc "Update ticket batch (admin only)" do
          success code: 200, message: "Ticket batch updated"
          failure [ { code: 401, message: "Unauthorized" },
                   { code: 403, message: "Forbidden" },
                   { code: 404, message: "Ticket batch not found" },
                   { code: 422, message: "Validation failed" } ]
        end
        params do
          requires :id, type: Integer
          optional :available_tickets, type: Integer
          optional :price, type: BigDecimal
          optional :sale_start, type: DateTime
          optional :sale_end, type: DateTime
        end
        put ":id" do
          admin_only!
          batch = ::TicketBatch.find(params[:id])
          event = batch.event
          declared_params = declared(params, include_missing: false).except(:id)
          result = ::TicketBatches::UpdateService.new(
            event: event,
            ticket_batch: batch,
            params: declared_params
          ).call
          raise EventRest::V1::Base::ApiException.new(result.failure, 422) unless result.success?
          TicketBatchSerializer.new(result.value!).serializable_hash
        end

        desc "Delete ticket batch (admin only)" do
          success code: 204, message: "Ticket batch deleted"
          failure [ { code: 401, message: "Unauthorized" },
                   { code: 403, message: "Forbidden" },
                   { code: 404, message: "Ticket batch not found" } ]
        end
        params do
          requires :id, type: Integer
        end
        delete ":id" do
          admin_only!
          batch = ::TicketBatch.find(params[:id])
          batch.destroy
          status 204
          body false
        end
      end
    end
  end
end
