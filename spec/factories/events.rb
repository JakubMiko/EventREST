FactoryBot.define do
  factory :event do
    name { "Sample Event" }
    description { "Sample description" }
    place { "Sample Place" }
    category { "music" }
    date { DateTime.now + 5.days }
  end

  trait :upcoming do
    date { DateTime.now + 5.days }
  end

  trait :past do
    date { DateTime.now - 5.days }
  end
end
