# frozen_string_literal: true

module Events
  class UpdateService < ApplicationService
    attr_reader :event, :params

    def initialize(event, params)
      @event = event
      @params = params
    end

    def call
      contract = EventContract.new
      result = contract.call(params)
      return Failure(result.errors.to_h.values.flatten.join(", ")) unless result.success?

      if event.update(params)
        Success(event)
      else
        Failure(event.errors.full_messages.join(", "))
      end
    end
  end
end
