FactoryBot.define do
  factory :ticket_batch do
    event
    available_tickets { 10 }
    price { BigDecimal("50.0") }
    sale_start { 1.day.ago }
    sale_end   { 2.days.from_now }

    trait :available_now do
      sale_start { 2.days.ago }
      sale_end   { 2.days.from_now }
      available_tickets { 5 }
    end

    trait :sold_out_now do
      sale_start { 2.days.ago }
      sale_end   { 1.day.from_now }
      available_tickets { 0 }
    end

    trait :expired do
      sale_start { 7.days.ago }
      sale_end   { 3.days.ago }
    end

    trait :inactive do
      sale_start { 5.days.from_now }
      sale_end   { 6.days.from_now }
    end
  end
end
