# frozen_string_literal: true

module EventRest
  module V1
    class Tickets < Grape::API
      resource :tickets do
        desc "List current user's tickets" do
          success code: 200, message: "Returns tickets of authenticated user"
          failure [ { code: 401, message: "Unauthorized" } ]
        end
        get do
          authorize!
          tickets = ::Ticket
                      .where(user_id: current_user.id)
                      .includes(:event, :order, order: :ticket_batch)
                      .order(created_at: :desc)
          TicketSerializer.new(tickets, include: %i[event order]).serializable_hash
        end

        desc "Show ticket details (owner or admin)" do
          success code: 200, message: "Returns single ticket"
          failure [
            { code: 401, message: "Unauthorized" },
            { code: 403, message: "Forbidden (not owner/admin)" },
            { code: 404, message: "Ticket not found" }
          ]
        end
        params do
          requires :id, type: Integer, desc: "Ticket ID"
        end
        get ":id" do
          authorize!
          ticket = ::Ticket.includes(:event, :order).find_by(id: params[:id])
          raise EventRest::V1::Base::ApiException.new("Ticket not found", 404) unless ticket
          unless current_user.admin? || ticket.user_id == current_user.id
            raise EventRest::V1::Base::ApiException.new("Forbidden", 403)
          end
          TicketSerializer.new(ticket, include: %i[event order]).serializable_hash
        end

        desc "Admin ticket search/list (filters + ticket_number exact)" do
          success code: 200, message: "Returns filtered ticket collection or single ticket"
          failure [
            { code: 401, message: "Unauthorized" },
            { code: 403, message: "Forbidden (not admin)" },
            { code: 404, message: "Ticket not found (when ticket_number provided)" }
          ]
        end
        params do
          optional :ticket_number, type: String, desc: "Exact ticket number (returns single ticket)"
          optional :user_id, type: Integer, desc: "Filter by user"
          optional :event_id, type: Integer, desc: "Filter by event"
          optional :order_id, type: Integer, desc: "Filter by order"
          optional :min_price, type: BigDecimal, desc: "Min price"
          optional :max_price, type: BigDecimal, desc: "Max price"
          optional :sort, type: String, values: %w[asc desc], desc: "Sort by created_at (default desc)"
        end
        get :admin do
          admin_only!
          declared_params = declared(params, include_missing: false)

          if declared_params[:ticket_number]
            ticket = ::Ticket.includes(:event, :order).find_by(ticket_number: declared_params[:ticket_number])
            raise EventRest::V1::Base::ApiException.new("Ticket not found", 404) unless ticket
            return TicketSerializer.new(ticket, include: %i[event order]).serializable_hash
          end

          scope = TicketsQuery.new(params: declared_params).call
          TicketSerializer.new(scope, include: %i[event order]).serializable_hash
        end
      end
    end
  end
end
