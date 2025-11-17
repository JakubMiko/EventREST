# frozen_string_literal: true


class EventsQuery
  attr_reader :params

  def initialize(params:)
    @params = params
  end

  def call
    scope = Event.limit(10)
    scope = scope.where(category: params[:category]) if params[:category]
    scope = scope.where("date >= ?", Time.now) if params[:upcoming]
    scope = scope.where("date < ?", Time.now) if params[:past]
    scope
  end
end
