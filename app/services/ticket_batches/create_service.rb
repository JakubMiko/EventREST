# frozen_string_literal: true

module TicketBatches
  class CreateService < ApplicationService
    attr_reader :event, :params

    def initialize(event:, params:)
      @event  = event
      @params = params
    end

    def call
      contract = TicketBatches::CreateContract.new(
        event: event,
        existing_batches: event.ticket_batches.where.not(id: nil)
      )
      result = contract.call(params.to_h)
      return Failure(result.errors.to_h.values.flatten.join(", ")) unless result.success?

      batch = event.ticket_batches.new(result.to_h)
      batch.save ? Success(batch) : Failure(batch.errors.full_messages.join(", "))
    end
  end
end
