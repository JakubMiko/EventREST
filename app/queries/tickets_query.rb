# frozen_string_literal: true

class TicketsQuery
  attr_reader :params, :relation

  def initialize(params:, relation: Ticket.all)
    @params = params
    @relation = relation
  end

  def call
    scope = relation
              .includes(:event, :order, order: :ticket_batch)

    scope = scope.where(user_id: params[:user_id]) if params[:user_id]
    scope = scope.where(event_id: params[:event_id]) if params[:event_id]
    scope = scope.where(order_id: params[:order_id]) if params[:order_id]
    scope = scope.where("price >= ?", params[:min_price]) if params[:min_price]
    scope = scope.where("price <= ?", params[:max_price]) if params[:max_price]

    direction = params[:sort] || "desc"
    scope.order(created_at: direction)
  end
end
