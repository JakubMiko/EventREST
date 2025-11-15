# frozen_string_literal: true

class TicketOrderSerializer < BaseSerializer
  set_type :order

  attributes :id, :status, :total_price, :quantity, :created_at
end
