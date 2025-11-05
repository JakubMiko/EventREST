# frozen_string_literal: true

module TicketBatches
  class CreateContract < ApplicationContract
    option :event
    option :existing_batches, default: -> { [] }

    params do
      required(:available_tickets).filled(:integer, gt?: 0)
      required(:price).filled(:decimal, gt?: 0)
      required(:sale_start).filled(:date_time)
      required(:sale_end).filled(:date_time)
    end

    rule(:sale_start, :sale_end) do
      if values[:sale_start] && values[:sale_end] && values[:sale_start] >= values[:sale_end]
        key(:sale_start).failure("The sale start date must be earlier than the end date")
      end
    end

    rule(:sale_end) do
      if value && event&.date && value > event.date
        key.failure("The sale end date must be earlier than the event date")
      end
    end

    rule(:sale_start, :sale_end) do
      if values[:sale_start] && values[:sale_end]
        existing_batches.each do |batch|
          unless values[:sale_end] < batch.sale_start || values[:sale_start] > batch.sale_end
            key(:sale_start).failure("The sales period conflicts with another ticket batch")
            break
          end
        end
      end
    end
  end
end
