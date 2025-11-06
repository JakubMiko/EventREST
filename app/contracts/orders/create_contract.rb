# frozen_string_literal: true

module Orders
  class CreateContract < ApplicationContract
    option :ticket_batch

    params do
      required(:quantity).filled(:integer, gt?: 0)
    end

    rule(:quantity) do
      if ticket_batch && value > ticket_batch.available_tickets
        key.failure("is greater than available tickets (#{ticket_batch.available_tickets})")
      end
    end

    rule(:quantity) do
      now = Time.current
      if ticket_batch && ticket_batch.sale_start && ticket_batch.sale_end
        if ticket_batch.sale_start > now || ticket_batch.sale_end < now
          key.failure("Sales window closed")
        end
      else
        key.failure("Sales window closed")
      end
    end
  end
end
