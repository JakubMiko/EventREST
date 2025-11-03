class Order < ApplicationRecord
  belongs_to :user
  belongs_to :ticket_batch
  has_many :tickets, dependent: :destroy
  has_one :event, through: :ticket_batch

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :total_price, presence: true, numericality: { greater_than: 0 }

  enum :status, { pending: "pending", paid: "paid", cancelled: "cancelled" }
end