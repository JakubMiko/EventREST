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

      if payload["date"].respond_to?(:to_datetime)
        payload["date"] = payload["date"].to_datetime
      end

      result = EventContract.new.call(payload)
      return Failure(result.errors.to_h.values.flatten.join(", ")) unless result.success?

      event.assign_attributes(params)
      if event.save
        Success(event)
      else
        Failure(event.errors.full_messages.join(", "))
      end
    end
  end
end
