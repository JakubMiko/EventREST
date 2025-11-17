# frozen_string_literal: true

class EventSerializer < BaseSerializer
  set_type :event

  has_many :ticket_batches, serializer: TicketBatchSerializer
  has_many :tickets, serializer: TicketSerializer

  attributes :id, :name, :description, :place, :date, :category, :created_at, :updated_at

  attribute :past do |object|
    object.past?
  end
end
