# frozen_string_literal: true

require "dry/monads/result"

class ApplicationService
  include Dry::Monads[:result]
end
