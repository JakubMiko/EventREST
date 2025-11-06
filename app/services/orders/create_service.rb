# frozen_string_literal: true

module Orders
  class CreateService < ApplicationService
    attr_reader :ticket_batch, :quantity, :current_user

    def initialize(ticket_batch:, quantity:, current_user:)
      @ticket_batch = ticket_batch
      @quantity     = quantity.to_i
      @current_user = current_user
    end

    def call
      Order.transaction do
        ticket_batch.lock!

        result = Orders::CreateContract.new(ticket_batch: ticket_batch).call(quantity: quantity)
        return Failure(result.errors.to_h.values.flatten.join(", ")) unless result.success?

        order = Order.new(
          user: current_user,
          ticket_batch: ticket_batch,
          quantity: quantity,
          total_price: ticket_batch.price * quantity,
          status: "pending"
        )

        ticket_batch.available_tickets -= quantity

        if order.save && ticket_batch.save
          quantity.times do
            Ticket.create!(
              order: order,
              user_id: current_user.id,
              event_id: ticket_batch.event_id,
              price: ticket_batch.price,
              ticket_number: SecureRandom.hex(10)
            )
          end
          Success(order)
        else
          Failure((order.errors.full_messages + ticket_batch.errors.full_messages).uniq.join(", "))
        end
      end
    end
  end
end
