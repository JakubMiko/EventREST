# frozen_string_literal: true

class TicketSerializer < BaseSerializer
  set_type :ticket

  belongs_to :event, serializer: EventSerializer
  belongs_to :order, serializer: OrderSerializer
  belongs_to :user, serializer: UserSerializer

  attributes :id, :ticket_number, :price, :event_id, :order_id, :user_id, :created_at, :updated_at
end
