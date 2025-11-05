# frozen_literal_string: true

class EventContract < ApplicationContract
  params do
    required(:name).filled(:string)
    required(:description).filled(:string)
    required(:place).filled(:string)
    required(:category).filled(:string)
    required(:date).filled
    optional(:image)
  end

  rule(:date) do
    dt =
      if value.respond_to?(:to_datetime)
        value.to_datetime
      elsif value.is_a?(String)
        DateTime.iso8601(value) rescue nil
      end

    key.failure("must be a date time") unless dt
    key.failure("The event date must be in the future") if dt && dt < DateTime.now
  end
end
