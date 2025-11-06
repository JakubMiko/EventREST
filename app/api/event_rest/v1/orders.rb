# frozen_string_literal: true

module EventRest
  module V1
    class Orders < Grape::API
      resource :orders do
        desc "Create order (user)"
        params do
          requires :ticket_batch_id, type: Integer
          requires :quantity, type: Integer
        end
        post do
          authorize!
          batch = ::TicketBatch.find(params[:ticket_batch_id])

          result = ::Orders::CreateService.new(
            ticket_batch: batch,
            quantity: params[:quantity],
            current_user: current_user
          ).call

          raise EventRest::V1::Base::ApiException.new(result.failure, 422) unless result.success?

          status 201
          OrderSerializer.new(result.value!, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "Show current_user orders"
        get do
          authorize!
          orders = ::Order
                     .where(user_id: current_user.id)
                     .includes(:tickets, :ticket_batch, ticket_batch: :event)
                     .order(created_at: :desc)

          OrderSerializer.new(orders, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "Show order details: admin can view any order, user only their own"
        params do
          requires :id, type: Integer
        end
        get ":id" do
          authorize!
          order = ::Order.includes(:tickets, :ticket_batch, ticket_batch: :event).find(params[:id])
          unless current_user.admin? || order.user_id == current_user.id
            raise EventRest::V1::Base::ApiException.new("Forbidden", 403)
          end

          OrderSerializer.new(order, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "All orders (admin, optional user_id filter)"
        params do
          optional :user_id, type: Integer, desc: "Filter orders by user ID"
        end
        get :all do
          admin_only!
          scope = ::Order.includes(:tickets, :ticket_batch, ticket_batch: :event).order(created_at: :desc)
          scope = scope.where(user_id: params[:user_id]) if params[:user_id]
          OrderSerializer.new(scope, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "Cancel order (owner or admin)"
        params do
          requires :id, type: Integer
        end
        put ":id/cancel" do
          authorize!
          order = ::Order.find(params[:id])
          result = ::Orders::CancelService.new(order: order, actor: current_user).call
          raise EventRest::V1::Base::ApiException.new(result.failure, 403) if result.failure? && result.failure == "Forbidden"
          raise EventRest::V1::Base::ApiException.new(result.failure, 422) unless result.success?

          OrderSerializer.new(result.value!, include: %i[tickets ticket_batch]).serializable_hash
        end

        desc "Pay order (owner or admin)"
        params do
          requires :id, type: Integer
          optional :amount, type: BigDecimal, desc: "Optional verification; must equal order.total_price"
          optional :payment_method, type: String, desc: "e.g. test, card_declined"
          optional :force_payment_status, type: String, values: %w[success fail], desc: "Force success/fail for tests"
        end
        post ":id/pay" do
          authorize!
          order = ::Order.find(params[:id])

          result = ::Orders::PayService.new(
            order: order,
            actor: current_user,
            amount: params[:amount],
            payment_method: params[:payment_method],
            force_payment_status: params[:force_payment_status]
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
