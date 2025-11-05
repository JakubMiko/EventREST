# frozen_string_literal: true

module Events
  class CreateService < ApplicationService
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def call
      result = Events::CreateContract.new.call(params)
      return Failure(result.errors.to_h.values.flatten.join(", ")) unless result.success?

      event = Event.new(result.to_h)
      event.save ? Success(event) : Failure(event.errors.full_messages.join(", "))
    end
  end
end
