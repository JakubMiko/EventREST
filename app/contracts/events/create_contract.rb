# frozen_string_literal: true

module Events
  class CreateContract < ApplicationContract
    params do
      required(:name).filled(:string)
      required(:description).filled(:string)
      required(:place).filled(:string)
      required(:category).filled(:string)
      required(:date).filled(:date_time)
      optional(:image)
    end

    rule(:date) do
      key.failure("The event date must be in the future") if value && value < Time.current
    end
  end
end
