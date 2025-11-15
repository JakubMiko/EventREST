# frozen_string_literal: true

class OrderUserSerializer < BaseSerializer
  set_type :user

  attributes :id, :email, :first_name, :last_name
end
