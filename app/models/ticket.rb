class Ticket < ApplicationRecord
  belongs_to :order
  belongs_to :user
  belongs_to :event

  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :ticket_number, presence: true, uniqueness: true
end
