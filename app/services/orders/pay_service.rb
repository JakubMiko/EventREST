# frozen_string_literal: true

module Orders
  class PayService < ApplicationService
    attr_reader :order, :actor, :amount, :payment_method, :force_payment_status

    def initialize(order:, actor:, amount: nil, payment_method: "test", force_payment_status: nil)
      @order = order
      @actor = actor
      @amount = amount
      @payment_method = payment_method
      @force_payment_status = force_payment_status
    end

    def call
      return Failure("Forbidden") unless actor&.admin? || order.user_id == actor&.id
      return Failure("Invalid status") unless order.status == "pending"

      if amount
        return Failure("Amount mismatch") unless BigDecimal(amount.to_s) == BigDecimal(order.total_price.to_s)
      end

      if force_payment_status == "fail" || payment_method == "card_declined"
        return Failure("Payment declined")
      end

      Order.transaction do
        order.update!(status: "paid")
      end

      Success(order)
    end
  end
end
