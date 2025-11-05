# frozen_string_literal: true

module Events
  class UpdateService < ApplicationService
    attr_reader :event, :params

    def initialize(event, params)
      @event  = event
      @params = params.to_h.stringify_keys
    end

    def call
      result = Events::UpdateContract.new.call(params)
      return Failure(result.errors.to_h.values.flatten.join(", ")) unless result.success?

      event.assign_attributes(result.to_h)
      event.save ? Success(event) : Failure(event.errors.full_messages.join(", "))
    end
  end
end
