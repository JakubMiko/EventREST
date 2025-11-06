# frozen_string_literal: true

module Orders
  class CancelService < ApplicationService
    attr_reader :order, :actor, :restore_stock

    def initialize(order:, actor:, restore_stock: true)
      @order = order
      @actor = actor
      @restore_stock = restore_stock
    end

    def call
      return Failure("Forbidden") unless actor&.admin? || order.user_id == actor&.id
      return Failure("Invalid status") unless order.status == "pending"

      Order.transaction do
        if restore_stock && order.ticket_batch
          order.ticket_batch.lock!
          order.ticket_batch.update!(available_tickets: order.ticket_batch.available_tickets + order.quantity)
        end
        order.update!(status: "cancelled")
      end

      Success(order)
    end
  end
end
