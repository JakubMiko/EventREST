# frozen_literal_string: true

class EventContract < ApplicationContract
  params do
    required(:name).filled(:string)
    required(:description).filled(:string)
    required(:place).filled(:string)
    required(:category).filled(:string)
    required(:date).filled(:date_time)
    optional(:image)
  end

  rule(:date) do
    if value && value < DateTime.now
      key.failure("The event date must be in the future")
    end
  end
end
