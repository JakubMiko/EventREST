FactoryBot.define do
  factory :order do
    user
    ticket_batch
    quantity { 2 }
    total_price { 100.0 }
    status { "pending" }
  end
end
