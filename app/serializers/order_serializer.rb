# frozen_string_literal: true

class OrderSerializer < BaseSerializer
  set_type :order

  belongs_to :user, serializer: UserSerializer
  belongs_to :ticket_batch, serializer: TicketBatchSerializer
  has_many :tickets, serializer: TicketSerializer
  belongs_to :event, serializer: EventSerializer

  attributes :id, :user_id, :ticket_batch_id, :quantity, :total_price, :status, :created_at, :updated_at
end
