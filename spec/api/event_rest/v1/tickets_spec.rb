# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tickets API", type: :request do
  let(:password) { "password123" }
  let(:admin) { create(:user, email: "admin@example.com", password: password, admin: true) }
  let(:user) { create(:user, email: "user@example.com", password: password, admin: false) }
  let(:other_user) { create(:user, email: "other@example.com", password: password, admin: false) }

  let(:admin_token) { JWT.encode({ user_id: admin.id }, Rails.application.secret_key_base) }
  let(:user_token)  { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }
  let(:other_token) { JWT.encode({ user_id: other_user.id }, Rails.application.secret_key_base) }

  let!(:event1) { create(:event) }
  let!(:event2) { create(:event) }

  let!(:batch1) { create(:ticket_batch, event: event1, price: BigDecimal("80.0")) }
  let!(:batch2) { create(:ticket_batch, event: event2, price: BigDecimal("120.0")) }

  let!(:order1) { create(:order, user: user, ticket_batch: batch1, quantity: 2, total_price: 160.0, status: "pending") }
  let!(:order2) { create(:order, user: other_user, ticket_batch: batch2, quantity: 1, total_price: 120.0, status: "paid") }

  let!(:t1) { create(:ticket, user: user, event: event1, order: order1, price: 80.0, ticket_number: "AAA111") }
  let!(:t2) { create(:ticket, user: user, event: event1, order: order1, price: 80.0, ticket_number: "BBB222") }
  let!(:t3) { create(:ticket, user: other_user, event: event2, order: order2, price: 120.0, ticket_number: "CCC333") }

  describe "GET /api/v1/tickets (current user list)" do
    it "returns only current user's tickets" do
      get "/api/v1/tickets", headers: { "Authorization" => "Bearer #{user_token}" }

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      ids = json["data"].map { |it| it["attributes"]["id"] }
      expect(ids).to contain_exactly(t1.id, t2.id)
    end

    it "returns 401 when unauthorized" do
      get "/api/v1/tickets"
      expect(response).to have_http_status(401)
    end

    context "serialization" do
      it "includes event and order (minimal) in the response" do
        get "/api/v1/tickets", headers: { "Authorization" => "Bearer #{user_token}" }

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)

        # Verify each ticket has event and order relationships
        json["data"].each do |ticket_data|
          expect(ticket_data["relationships"]).to have_key("event")
          expect(ticket_data["relationships"]).to have_key("order")
        end

        # Verify included section has event and order
        included_types = json["included"].map { |i| i["type"] }.uniq
        expect(included_types).to include("event", "order")

        # Verify order serializer is minimal (TicketOrderSerializer - no tickets relation)
        included_orders = json["included"].select { |i| i["type"] == "order" }
        included_orders.each do |order_data|
          # Should have basic order fields
          expect(order_data["attributes"]).to have_key("status")
          expect(order_data["attributes"]).to have_key("total_price")
          expect(order_data["attributes"]).to have_key("quantity")
          # Should NOT have tickets relationship (minimal serializer prevents duplication)
          expect(order_data).not_to have_key("relationships")
        end
      end
    end
  end

  describe "GET /api/v1/tickets/:id (show)" do
    it "allows owner to see own ticket" do
      get "/api/v1/tickets/#{t1.id}", headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["id"]).to eq(t1.id)
    end

    it "returns 403 for non-owner non-admin" do
      get "/api/v1/tickets/#{t1.id}", headers: { "Authorization" => "Bearer #{other_token}" }
      expect(response).to have_http_status(403)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Forbidden")
    end

    it "allows admin to see any ticket" do
      get "/api/v1/tickets/#{t1.id}", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(200)
    end

    it "returns 404 when ticket not found" do
      get "/api/v1/tickets/999999", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Ticket not found")
    end
  end

  describe "GET /api/v1/tickets/admin (admin search/list)" do
    it "returns all tickets for admin" do
      get "/api/v1/tickets/admin", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |it| it["attributes"]["id"] }
      expect(ids).to contain_exactly(t1.id, t2.id, t3.id)
    end

    it "filters by user_id" do
      get "/api/v1/tickets/admin",
          params: { user_id: user.id },
          headers: { "Authorization" => "Bearer #{admin_token}" }

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |it| it["attributes"]["id"] }
      expect(ids).to contain_exactly(t1.id, t2.id)
    end

    it "filters by event_id" do
      get "/api/v1/tickets/admin",
          params: { event_id: event2.id },
          headers: { "Authorization" => "Bearer #{admin_token}" }

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |it| it["attributes"]["id"] }
      expect(ids).to contain_exactly(t3.id)
    end

    it "filters by order_id" do
      get "/api/v1/tickets/admin",
          params: { order_id: order1.id },
          headers: { "Authorization" => "Bearer #{admin_token}" }

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |it| it["attributes"]["id"] }
      expect(ids).to contain_exactly(t1.id, t2.id)
    end

    it "filters by price range" do
      get "/api/v1/tickets/admin",
          params: { min_price: 100, max_price: 130 },
          headers: { "Authorization" => "Bearer #{admin_token}" }

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |it| it["attributes"]["id"] }
      expect(ids).to contain_exactly(t3.id)
    end

    it "finds by exact ticket_number (returns a single ticket)" do
      get "/api/v1/tickets/admin",
          params: { ticket_number: "CCC333" },
          headers: { "Authorization" => "Bearer #{admin_token}" }

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_a(Hash)
      expect(json["data"]["attributes"]["id"]).to eq(t3.id)
    end

    it "returns 404 when ticket_number not found" do
      get "/api/v1/tickets/admin",
          params: { ticket_number: "NOT-EXIST" },
          headers: { "Authorization" => "Bearer #{admin_token}" }

      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Ticket not found")
    end

    it "returns 403 for non-admin" do
      get "/api/v1/tickets/admin", headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(403)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Forbidden")
    end

    it "returns 401 when unauthorized" do
      get "/api/v1/tickets/admin"
      expect(response).to have_http_status(401)
    end

    it "applies multiple filters together (intersection)" do
      get "/api/v1/tickets/admin",
          params: {
            user_id: user.id,
            event_id: event1.id,
            order_id: order1.id,
            min_price: 80,
            max_price: 80,
            sort: "asc"
          },
          headers: { "Authorization" => "Bearer #{admin_token}" }

      expect(response).to have_http_status(200), "Body: #{response.body}"
      json = JSON.parse(response.body)
      ids = json["data"].map { |it| it["attributes"]["id"] }
      expect(ids).to contain_exactly(t1.id, t2.id)
    end

    context "serialization" do
      it "includes event, order, and user (minimal) in admin response" do
        get "/api/v1/tickets/admin", headers: { "Authorization" => "Bearer #{admin_token}" }

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)

        json["data"].each do |ticket_data|
          expect(ticket_data["relationships"]).to have_key("event")
          expect(ticket_data["relationships"]).to have_key("order")
          expect(ticket_data["relationships"]).to have_key("user")
        end

        included_types = json["included"].map { |i| i["type"] }.uniq
        expect(included_types).to include("event", "order", "user")

        included_users = json["included"].select { |i| i["type"] == "user" }
        included_users.each do |user_data|
          expect(user_data["attributes"]).to have_key("email")
          expect(user_data["attributes"]).to have_key("first_name")
          expect(user_data["attributes"]).to have_key("last_name")
          expect(user_data).not_to have_key("relationships")
        end

        included_orders = json["included"].select { |i| i["type"] == "order" }
        included_orders.each do |order_data|
          expect(order_data["attributes"]).to have_key("status")
          expect(order_data["attributes"]).to have_key("total_price")
          expect(order_data).not_to have_key("relationships")
        end
      end
    end
  end
end
