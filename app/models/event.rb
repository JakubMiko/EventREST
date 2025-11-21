class Event < ApplicationRecord
  has_many :ticket_batches, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_one_attached :image

  after_commit :invalidate_events_cache

  scope :upcoming, -> { where("date > ?", DateTime.now).order(date: :asc) }
  scope :past, -> { where("date <= ?", DateTime.now).order(date: :desc) }

  private

  def invalidate_events_cache
    Rails.cache.delete_matched("events:*")
  rescue => e
    Rails.logger.error("Failed to invalidate events cache: #{e.message}")
  end

  enum :category, {
    music: "music",
    theater: "theater",
    sports: "sports",
    comedy: "comedy",
    conference: "conference",
    festival: "festival",
    exhibition: "exhibition",
    other: "other"
  }

  def past?
    date <= DateTime.now
  end
end
