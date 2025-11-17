# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Orders API", type: :request do
  let(:password) { "password123" }
  let(:admin) { create(:user, email: "admin@example.com", password: password, admin: true) }
  let(:user) { create(:user, email: "user@example.com", password: password, admin: false) }
  let(:other_user) { create(:user, email: "other@example.com", password: password, admin: false) }

  let(:admin_token) { JWT.encode({ user_id: admin.id }, Rails.application.secret_key_base) }
  let(:user_token)  { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }
  let(:other_token) { JWT.encode({ user_id: other_user.id }, Rails.application.secret_key_base) }

  let!(:event) { create(:event) }
  let!(:batch_available) { create(:ticket_batch, :available_now, event: event, available_tickets: 10, price: BigDecimal("80.0")) }
  let!(:batch_future)    { create(:ticket_batch, :inactive, event: event, available_tickets: 10, price: BigDecimal("80.0")) }

  describe "POST /api/v1/orders (create order)" do
    it "creates order when authorized and stock available" do
      params = { ticket_batch_id: batch_available.id, quantity: 2 }

      expect {
        post "/api/v1/orders", params: params, headers: { "Authorization" => "Bearer #{user_token}" }
      }.to change(Order, :count).by(1)
       .and change(Ticket, :count).by(2)

      expect(response).to have_http_status(201)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["status"]).to eq("pending")
      expect(batch_available.reload.available_tickets).to eq(8)
    end

    it "returns 422 when quantity exceeds stock" do
      params = { ticket_batch_id: batch_available.id, quantity: 999 }

      post "/api/v1/orders", params: params, headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to match(/greater than available/i)
    end

    it "returns 422 when sales window is closed" do
      params = { ticket_batch_id: batch_future.id, quantity: 1 }

      post "/api/v1/orders", params: params, headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to match(/Sales window closed/i)
    end

    it "returns 401 when unauthorized" do
      post "/api/v1/orders", params: { ticket_batch_id: batch_available.id, quantity: 1 }
      expect(response).to have_http_status(401)
    end

    context "serialization" do
      it "includes event, tickets, and ticket_batch in the response" do
        params = { ticket_batch_id: batch_available.id, quantity: 3 }
        post "/api/v1/orders", params: params, headers: { "Authorization" => "Bearer #{user_token}" }

        expect(response).to have_http_status(201)
        json = JSON.parse(response.body)

        expect(json["data"]["relationships"]).to have_key("event")
        expect(json["data"]["relationships"]).to have_key("tickets")
        expect(json["data"]["relationships"]).to have_key("ticket_batch")

        ticket_ids = json["data"]["relationships"]["tickets"]["data"].map { |t| t["id"] }
        expect(ticket_ids.size).to eq(3)

        expect(json["included"].map { |i| i["type"] }).to include("ticket", "event", "ticket_batch")

        included_tickets = json["included"].select { |i| i["type"] == "ticket" }
        expect(included_tickets.size).to eq(3)

        included_event = json["included"].find { |i| i["type"] == "event" }
        expect(included_event["id"]).to eq(event.id.to_s)

        included_batch = json["included"].find { |i| i["type"] == "ticket_batch" }
        expect(included_batch["id"]).to eq(batch_available.id.to_s)
      end
    end
  end

  describe "GET /api/v1/orders (current_user orders)" do
    let!(:my_order1) { create(:order, user: user, ticket_batch: batch_available, quantity: 1, total_price: 80.0, status: "pending") }
    let!(:my_order2) { create(:order, user: user, ticket_batch: batch_available, quantity: 2, total_price: 160.0, status: "paid") }
    let!(:other_order) { create(:order, user: other_user, ticket_batch: batch_available, quantity: 1, total_price: 80.0, status: "pending") }

    it "returns only current user's orders" do
      get "/api/v1/orders", headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |o| o["attributes"]["id"] }
      expect(ids).to include(my_order1.id, my_order2.id)
      expect(ids).not_to include(other_order.id)
    end

    it "returns 401 when unauthorized" do
      get "/api/v1/orders"
      expect(response).to have_http_status(401)
    end
  end

  describe "GET /api/v1/orders/:id (show)" do
    let!(:user_order) { create(:order, user: user, ticket_batch: batch_available, quantity: 1, total_price: 80.0, status: "pending") }

    it "shows own order for user" do
      get "/api/v1/orders/#{user_order.id}", headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["id"]).to eq(user_order.id)
    end

    it "returns 403 when non-owner non-admin tries to view" do
      get "/api/v1/orders/#{user_order.id}", headers: { "Authorization" => "Bearer #{other_token}" }
      expect(response).to have_http_status(403)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Forbidden")
    end

    it "admin can view any order" do
      get "/api/v1/orders/#{user_order.id}", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(200)
    end
  end

  describe "GET /api/v1/orders/all (admin index with optional filter)" do
    let!(:o1) { create(:order, user: user, ticket_batch: batch_available, quantity: 1, total_price: 80.0, status: "pending") }
    let!(:o2) { create(:order, user: other_user, ticket_batch: batch_available, quantity: 2, total_price: 160.0, status: "paid") }

    it "returns all orders for admin" do
      get "/api/v1/orders/all", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |o| o["attributes"]["id"] }
      expect(ids).to include(o1.id, o2.id)
    end

    it "filters by user_id for admin" do
      get "/api/v1/orders/all", params: { user_id: user.id }, headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |o| o["attributes"]["id"] }
      expect(ids).to contain_exactly(o1.id)
    end

    it "returns 403 for non-admin" do
      get "/api/v1/orders/all", headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(403)
    end

    it "returns 401 when unauthorized" do
      get "/api/v1/orders/all"
      expect(response).to have_http_status(401)
    end

    context "serialization" do
      it "includes event, ticket_batch, and user (minimal) in the response" do
        get "/api/v1/orders/all", headers: { "Authorization" => "Bearer #{admin_token}" }

        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)

        json["data"].each do |order_data|
          expect(order_data["relationships"]).to have_key("event")
          expect(order_data["relationships"]).to have_key("ticket_batch")
          expect(order_data["relationships"]).to have_key("user")
        end

        included_types = json["included"].map { |i| i["type"] }.uniq
        expect(included_types).to include("event", "ticket_batch", "user")

        included_users = json["included"].select { |i| i["type"] == "user" }
        included_users.each do |user_data|
          expect(user_data["attributes"]).to have_key("email")
          expect(user_data["attributes"]).to have_key("first_name")
          expect(user_data["attributes"]).to have_key("last_name")
          expect(user_data).not_to have_key("relationships")
        end


        included_tickets = json["included"]&.select { |i| i["type"] == "ticket" }
        expect(included_tickets).to be_empty
      end
    end
  end

  describe "PUT /api/v1/orders/:id/cancel" do
    let!(:cancel_batch) { create(:ticket_batch, :available_now, event: event, available_tickets: 5, price: BigDecimal("80.0")) }
    let!(:pending_order) { create(:order, user: user, ticket_batch: cancel_batch, quantity: 2, total_price: 160.0, status: "pending") }
    let!(:paid_order)    { create(:order, user: user, ticket_batch: cancel_batch, quantity: 1, total_price: 80.0, status: "paid") }

    it "cancels pending order by owner and restores stock" do
      expect {
        put "/api/v1/orders/#{pending_order.id}/cancel", headers: { "Authorization" => "Bearer #{user_token}" }
      }.to change { pending_order.reload.status }.from("pending").to("cancelled")

      expect(response).to have_http_status(200)
      expect(cancel_batch.reload.available_tickets).to eq(7) # 5 + 2
    end

    it "returns 422 when status is not pending" do
      put "/api/v1/orders/#{paid_order.id}/cancel", headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Invalid status")
    end

    it "returns 403 for non-owner non-admin" do
      put "/api/v1/orders/#{pending_order.id}/cancel", headers: { "Authorization" => "Bearer #{other_token}" }
      expect(response).to have_http_status(403)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Forbidden")
    end

    it "admin can cancel any pending order" do
      put "/api/v1/orders/#{pending_order.id}/cancel", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(200)
      expect(pending_order.reload.status).to eq("cancelled")
    end

    it "returns 401 when unauthorized" do
      put "/api/v1/orders/#{pending_order.id}/cancel"
      expect(response).to have_http_status(401)
    end
  end

  describe "POST /api/v1/orders/:id/pay" do
    let!(:pay_order) { create(:order, user: user, ticket_batch: batch_available, quantity: 2, total_price: 160.0, status: "pending") }

    it "marks order as paid for owner on success" do
      post "/api/v1/orders/#{pay_order.id}/pay",
           params: { amount: "160.0", payment_method: "test" },
           headers: { "Authorization" => "Bearer #{user_token}" }

      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["status"]).to eq("paid")
    end

    it "returns 422 on amount mismatch" do
      post "/api/v1/orders/#{pay_order.id}/pay",
           params: { amount: "170.0", payment_method: "test" },
           headers: { "Authorization" => "Bearer #{user_token}" }

      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Amount mismatch")
    end

    it "returns 422 when forced to fail" do
      post "/api/v1/orders/#{pay_order.id}/pay",
           params: { amount: "160.0", force_payment_status: "fail" },
           headers: { "Authorization" => "Bearer #{user_token}" }

      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Payment declined")
    end

    it "returns 403 for non-owner non-admin" do
      post "/api/v1/orders/#{pay_order.id}/pay",
           params: { amount: "160.0" },
           headers: { "Authorization" => "Bearer #{other_token}" }

      expect(response).to have_http_status(403)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Forbidden")
    end

    it "returns 401 when unauthorized" do
      post "/api/v1/orders/#{pay_order.id}/pay", params: { amount: "160.0" }
      expect(response).to have_http_status(401)
    end
  end
end
