# frozen_string_literal: true

class TicketBatchSerializer < BaseSerializer
  set_type :ticket_batch

  belongs_to :event, serializer: EventSerializer

  attributes :id, :event_id, :available_tickets, :price, :sale_start, :sale_end, :created_at, :updated_at
end
