# frozen_string_literal: true

class TicketBatchQuery
  attr_reader :relation, :state, :order, :now

  def initialize(relation:, state: "available", order: "asc", now: Time.current)
    @relation = relation
    @state = state.to_s
    @order = %w[asc desc].include?(order.to_s.downcase) ? order.to_s.downcase : "asc"
    @now = now
  end

  def call
    scope = apply_state(relation)
    scope.order("sale_start #{order}")
  end

  private

  def apply_state(scope)
    case state
    when "available"
      scope.where("available_tickets > 0 AND sale_start <= ? AND sale_end >= ?", now, now)
    when "sold_out"
      scope.where("available_tickets = 0 AND sale_start <= ? AND sale_end >= ?", now, now)
    when "expired"
      scope.where("sale_end < ?", now)
    when "inactive"
      scope.where("sale_start > ?", now)
    else
      scope
    end
  end
end
