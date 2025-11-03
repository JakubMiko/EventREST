class TicketBatch < ApplicationRecord
  belongs_to :event
  has_many :orders, dependent: :destroy
end
