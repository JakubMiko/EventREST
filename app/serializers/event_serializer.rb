# frozen_string_literal: true

class EventSerializer < BaseSerializer
  set_type :event

  has_many :ticket_batches, serializer: TicketBatchSerializer
  has_many :tickets, serializer: TicketSerializer

  attributes :id, :name, :description, :place, :date, :category, :created_at, :updated_at

  attribute :image_url do |object|
    if object.image.attached?
      Rails.application.routes.url_helpers.rails_blob_url(object.image, only_path: true)
    end
  end

  attribute :past do |object|
    object.past?
  end
end
