FactoryBot.define do
  factory :ticket do
    order
    user
    event
    price { 25.0 }
    ticket_number { Faker::Number.unique.number(digits: 10).to_s }
  end
end
