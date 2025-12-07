# frozen_string_literal: true

class OrderListSerializer < BaseSerializer
  set_type :order

  attributes :id, :user_id, :ticket_batch_id, :quantity, :total_price, :status, :created_at, :updated_at
end
