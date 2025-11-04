# frozen_string_literal: true

module Events
  class CreateService < ApplicationService
    attr_reader :params

    def initialize(params)
      @params = params
    end

    def call
      valid, error_message = valid_params?
      return Failure(error_message) unless valid

      event = Event.new(params)
      if event.save
        Success(event)
      else
        Failure(event.errors.full_messages.join(", "))
      end
    end

    private

    def valid_params?
      contract = EventContract.new
      result = contract.call(params)
      [ result.success?, result.errors.to_h.values.flatten.join(", ") ]
    end
  end
end
