# frozen_string_literal: true

module Events
  class UpdateContract < ApplicationContract
    params do
      optional(:name).filled(:string)
      optional(:description).filled(:string)
      optional(:place).filled(:string)
      optional(:category).filled(:string)
      optional(:date).filled(:date_time)
      optional(:image)
    end

    rule(:date) do
      key.failure("The event date must be in the future") if value && value < Time.current
    end
  end
end
