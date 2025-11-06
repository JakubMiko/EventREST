# frozen_string_literal: true

module EventRest
  module V1
    class Orders < Grape::API
      resource :orders do
        desc "Create order (user)" do
          success code: 201, message: "Order created. Returns order with generated tickets"
          failure [
            { code: 401, message: "Unauthorized" },
            { code: 422, message: "Validation failed (stock / sales window / quantity)" }
          ]
        end
        params do
          requires :ticket_batch_id, type: Integer, desc: "ID of ticket batch"
          requires :quantity, type: Integer, desc: "Number of tickets to purchase (>0)"
        end
        post do
          authorize!
          declared_params = declared(params, include_missing: false)
          batch = ::TicketBatch.find(declared_params[:ticket_batch_id])

          result = ::Orders::CreateService.new(
            ticket_batch: batch,
            quantity: declared_params[:quantity],
            current_user: current_user
          ).call

            raise EventRest::V1::Base::ApiException.new(result.failure, 422) unless result.success?
            status 201
            OrderSerializer.new(result.value!, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "List current user's orders" do
          success code: 200, message: "Returns array of orders belonging to authenticated user"
          failure code: 401, message: "Unauthorized"
        end
        get do
          authorize!
          orders = ::Order
                     .where(user_id: current_user.id)
                     .includes(:tickets, :ticket_batch, ticket_batch: :event)
                     .order(created_at: :desc)
          OrderSerializer.new(orders, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "Show order details (admin any / user own)" do
          success code: 200, message: "Returns single order"
          failure [
            { code: 401, message: "Unauthorized" },
            { code: 403, message: "Forbidden (other user's order)" },
            { code: 404, message: "Order not found" }
          ]
        end
        params do
          requires :id, type: Integer, desc: "Order ID"
        end
        get ":id" do
          authorize!
          order = ::Order.includes(:tickets, :ticket_batch, ticket_batch: :event).find(params[:id])
          unless current_user.admin? || order.user_id == current_user.id
            raise EventRest::V1::Base::ApiException.new("Forbidden", 403)
          end
          OrderSerializer.new(order, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "List all orders (admin only, optional filter by user_id)" do
          success code: 200, message: "Returns all orders or filtered by user_id"
          failure [
            { code: 401, message: "Unauthorized" },
            { code: 403, message: "Forbidden (not admin)" }
          ]
        end
        params do
          optional :user_id, type: Integer, desc: "Filter by user ID"
        end
        get :all do
          admin_only!
          declared_params = declared(params, include_missing: false)
          scope = ::Order.includes(:tickets, :ticket_batch, ticket_batch: :event).order(created_at: :desc)
          scope = scope.where(user_id: declared_params[:user_id]) if declared_params[:user_id]
          OrderSerializer.new(scope, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "Cancel order (owner or admin)" do
          success code: 200, message: "Order cancelled"
          failure [
            { code: 401, message: "Unauthorized" },
            { code: 403, message: "Forbidden (not owner/admin)" },
            { code: 422, message: "Invalid status (not pending)" },
            { code: 404, message: "Order not found" }
          ]
        end
        params do
          requires :id, type: Integer, desc: "Order ID"
        end
        put ":id/cancel" do
          authorize!
          order = ::Order.find(params[:id])
          result = ::Orders::CancelService.new(order: order, actor: current_user).call
          raise EventRest::V1::Base::ApiException.new(result.failure, 403) if result.failure? && result.failure == "Forbidden"
          raise EventRest::V1::Base::ApiException.new(result.failure, 422) unless result.success?
          OrderSerializer.new(result.value!, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "Pay order (owner or admin, mocked payment)" do
          success code: 200, message: "Order paid"
          failure [
            { code: 401, message: "Unauthorized" },
            { code: 403, message: "Forbidden (not owner/admin)" },
            { code: 422, message: "Amount mismatch / Payment declined / Invalid status" },
            { code: 404, message: "Order not found" }
          ]
        end
        params do
          requires :id, type: Integer, desc: "Order ID"
          optional :amount, type: BigDecimal, desc: "Must match total_price if provided"
          optional :payment_method, type: String, desc: "test, card_declined"
          optional :force_payment_status, type: String, values: %w[success fail], desc: "Force outcome"
        end
        post ":id/pay" do
          authorize!
          declared_params = declared(params, include_missing: false)
          order = ::Order.find(declared_params[:id])

          result = ::Orders::PayService.new(
            order: order,
            actor: current_user,
            amount: declared_params[:amount],
            payment_method: declared_params[:payment_method],
            force_payment_status: declared_params[:force_payment_status]
          ).call

          raise EventRest::V1::Base::ApiException.new(result.failure, 403) if result.failure? && result.failure == "Forbidden"
          raise EventRest::V1::Base::ApiException.new(result.failure, 422) unless result.success?
          status 200
          OrderSerializer.new(result.value!, include: %i[tickets ticket_batch]).serializable_hash
        end
      end
    end
  end
end
