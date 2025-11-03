# frozen_string_literal: true

class TicketSerializer < BaseSerializer
  set_type :ticket

  belongs_to :order, serializer: OrderSerializer
  belongs_to :user, serializer: UserSerializer
  belongs_to :event, serializer: EventSerializer

  attributes :id, :order_id, :user_id, :event_id, :price, :ticket_number, :created_at, :updated_at
end
