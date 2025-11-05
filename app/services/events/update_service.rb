# frozen_string_literal: true

module Events
  class UpdateService < ApplicationService
    attr_reader :event, :params

    def initialize(event, params)
      @event  = event
      @params = params.to_h.stringify_keys
    end

    def call
      payload = event.attributes.merge(params)
      result  = EventContract.new.call(payload)
      return Failure(result.errors.to_h.values.flatten.join(", ")) unless result.success?

      event.assign_attributes(params)
      event.save ? Success(event) : Failure(event.errors.full_messages.join(", "))
    end
  end
end
