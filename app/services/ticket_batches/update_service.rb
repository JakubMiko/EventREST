# frozen_string_literal: true

module TicketBatches
  class UpdateService < ApplicationService
    attr_reader :event, :ticket_batch, :params

    def initialize(event:, ticket_batch:, params:)
      @event = event
      @ticket_batch = ticket_batch
      @params = params.to_h.stringify_keys
    end

    def call
      contract = TicketBatches::UpdateContract.new(
        event: event,
        current_batch: ticket_batch,
        existing_batches: event.ticket_batches.where.not(id: ticket_batch.id)
      )
      result = contract.call(params)
      return Failure(result.errors.to_h.values.flatten.join(", ")) unless result.success?

      ticket_batch.assign_attributes(result.to_h)
      ticket_batch.save ? Success(ticket_batch) : Failure(ticket_batch.errors.full_messages.join(", "))
    end
  end
end
