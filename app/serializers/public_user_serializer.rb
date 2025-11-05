# frozen_string_literal: true

class PublicUserSerializer < BaseSerializer
  set_type :user

  attributes :id, :email, :first_name, :last_name, :created_at
end
