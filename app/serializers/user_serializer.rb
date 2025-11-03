# frozen_string_literal: true

class UserSerializer < BaseSerializer
  set_type :user

  has_many :orders, serializer: OrderSerializer
  has_many :tickets, serializer: TicketSerializer

  attributes :id, :email, :first_name, :last_name, :admin, :created_at
end
