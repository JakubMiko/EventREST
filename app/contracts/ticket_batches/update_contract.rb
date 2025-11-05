# frozen_string_literal: true

module TicketBatches
  class UpdateContract < ApplicationContract
    option :event
    option :current_batch
    option :existing_batches, default: -> { [] }

    params do
      optional(:available_tickets).filled(:integer, gt?: 0)
      optional(:price).filled(:decimal, gt?: 0)
      optional(:sale_start).filled(:date_time)
      optional(:sale_end).filled(:date_time)
    end

    rule(:sale_start, :sale_end) do
      sale_start_value = values[:sale_start] || current_batch.sale_start
      sale_end_value   = values[:sale_end]   || current_batch.sale_end
      next unless sale_start_value && sale_end_value

      if sale_end_value <= sale_start_value
        key(:sale_start).failure("The sale start date must be earlier than the end date")
      end
    end

    rule(:sale_end) do
      if value && event&.date && value > event.date
        key.failure("The sale end date must be earlier than the event date")
      end
    end

    rule(:sale_start, :sale_end) do
      sale_start_value = values[:sale_start] || current_batch.sale_start
      sale_end_value   = values[:sale_end]   || current_batch.sale_end
      next unless sale_start_value && sale_end_value

      existing_batches.each do |other_batch|
        next if other_batch.id == current_batch.id
        next unless other_batch.sale_start && other_batch.sale_end

        overlaps = !(sale_end_value < other_batch.sale_start || sale_start_value > other_batch.sale_end)
        if overlaps
          key(:sale_start).failure("The sales period conflicts with another ticket batch")
          break
        end
      end
    end
  end
end
