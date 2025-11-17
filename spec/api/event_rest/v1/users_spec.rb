# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users API", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password, password_confirmation: password, email: "test@example.com") }
  let(:admin) { create(:user, password: password, password_confirmation: password, email: "admin@example.com", admin: true) }
  let(:token) { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }
  let(:admin_token) { JWT.encode({ user_id: admin.id }, Rails.application.secret_key_base) }

  describe "POST /api/v1/users/register" do
    it "registers a new user and returns JWT token" do
      post "/api/v1/users/register", params: {
        first_name: "Jan",
        last_name: "Kowalski",
        email: "nowy@example.com",
        password: "haslo123",
        password_confirmation: "haslo123"
      }
      expect(response).to have_http_status(201)
      json = JSON.parse(response.body)
      expect(json["token"]).to be_present
      expect(json["data"]).to be_present
      expect(json["data"]["data"]["attributes"]["email"]).to eq("nowy@example.com")
    end

    it "returns 422 if email taken" do
      create(:user, email: "nowy@example.com")
      post "/api/v1/users/register", params: {
        first_name: "Jan",
        last_name: "Kowalski",
        email: "nowy@example.com",
        password: "haslo123",
        password_confirmation: "haslo123"
      }
      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Email")
    end

    it "returns 422 if password confirmation does not match" do
      post "/api/v1/users/register", params: {
        first_name: "Jan",
        last_name: "Kowalski",
        email: "nowy2@example.com",
        password: "haslo123",
        password_confirmation: "innehaslo"
      }
      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("Password confirmation")
    end
  end

  describe "POST /api/v1/users/login" do
    it "returns JWT token and user data for valid credentials" do
      post "/api/v1/users/login", params: { email: user.email, password: password }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["token"]).to be_present
      expect(json["data"]).to be_present
      expect(json["data"]["data"]["attributes"]["email"]).to eq(user.email)
    end

    it "returns 401 for invalid password" do
      post "/api/v1/users/login", params: { email: user.email, password: "wrong" }
      expect(response).to have_http_status(401)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Invalid email or password")
    end

    it "returns 401 for non-existent email" do
      post "/api/v1/users/login", params: { email: "nope@example.com", password: "wrong" }
      expect(response).to have_http_status(401)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Invalid email or password")
    end
  end

  describe "GET /api/v1/users/current" do
    it "returns current user data when authorized" do
      get "/api/v1/users/current", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["email"]).to eq(user.email)
    end

    it "returns 401 when not authorized" do
      get "/api/v1/users/current"
      expect(response).to have_http_status(401)
    end
  end

  describe "GET /api/v1/users/public/:id" do
    it "returns public user profile" do
      get "/api/v1/users/public/#{user.id}"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["email"]).to eq(user.email)
    end

    it "returns 404 if user not found" do
      get "/api/v1/users/public/999999"
      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("User not found")
    end
  end

  describe "GET /api/v1/users/:id (admin only)" do
    it "returns full user data for admin" do
      get "/api/v1/users/#{user.id}", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["email"]).to eq(user.email)
    end

    it "returns 403 for non-admin" do
      get "/api/v1/users/#{user.id}", headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(403)
    end

    it "returns 404 if user not found" do
      get "/api/v1/users/999999", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("User not found")
    end
  end

  describe "PUT /api/v1/users/change_password" do
    it "changes password for logged-in user" do
      put "/api/v1/users/change_password", params: {
        current_password: password,
        password: "newpass123",
        password_confirmation: "newpass123"
      }, headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Password changed successfully")
    end

    it "returns 422 if current password is wrong" do
      put "/api/v1/users/change_password", params: {
        current_password: "wrong",
        password: "newpass123",
        password_confirmation: "newpass123"
      }, headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Current password is incorrect")
    end

    it "returns 422 if password confirmation does not match" do
      put "/api/v1/users/change_password", params: {
        current_password: password,
        password: "newpass123",
        password_confirmation: "otherpass"
      }, headers: { "Authorization" => "Bearer #{token}" }
      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Password confirmation does not match")
    end

    it "returns 401 if not authorized" do
      put "/api/v1/users/change_password", params: {
        current_password: password,
        password: "newpass123",
        password_confirmation: "newpass123"
      }
      expect(response).to have_http_status(401)
    end
  end

  describe "GET /api/v1/users (benchmark endpoint)" do
    let!(:user1) { create(:user, email: "user1@test.com", first_name: "John", last_name: "Doe") }
    let!(:user2) { create(:user, email: "user2@test.com", first_name: "Jane", last_name: "Smith") }
    let!(:user3) { create(:user, email: "user3@test.com", first_name: "Bob", last_name: "Johnson") }

    it "returns all users without authentication" do
      get "/api/v1/users"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].size).to eq(3)
    end

    it "returns users in JSON:API format" do
      get "/api/v1/users"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)

      first_user = json["data"].first
      expect(first_user).to have_key("id")
      expect(first_user).to have_key("type")
      expect(first_user).to have_key("attributes")
      expect(first_user["type"]).to eq("user")
    end

    it "includes expected user attributes" do
      get "/api/v1/users"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)

      user_data = json["data"].find { |u| u["id"] == user1.id.to_s }
      attributes = user_data["attributes"]

      expect(attributes).to have_key("id")
      expect(attributes).to have_key("email")
      expect(attributes).to have_key("first_name")
      expect(attributes).to have_key("last_name")
      expect(attributes).to have_key("created_at")
      expect(attributes["email"]).to eq("user1@test.com")
      expect(attributes["first_name"]).to eq("John")
      expect(attributes["last_name"]).to eq("Doe")
    end

    it "includes user relationships" do
      get "/api/v1/users"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)

      first_user = json["data"].first
      expect(first_user).to have_key("relationships")
      expect(first_user["relationships"]).to have_key("orders")
    end
  end

  describe "GET /api/v1/users/:id/orders (benchmark endpoint)" do
    let!(:test_user) { create(:user, email: "testuser@example.com") }
    let!(:event1) { create(:event, name: "Concert", date: 1.week.from_now) }
    let!(:event2) { create(:event, name: "Theater", date: 2.weeks.from_now) }
    let!(:batch1) { create(:ticket_batch, event: event1, price: 50, available_tickets: 100) }
    let!(:batch2) { create(:ticket_batch, event: event2, price: 75, available_tickets: 100) }
    let!(:order1) { create(:order, user: test_user, ticket_batch: batch1, quantity: 2, status: "paid", total_price: 100) }
    let!(:order2) { create(:order, user: test_user, ticket_batch: batch2, quantity: 3, status: "pending", total_price: 225) }
    let!(:other_user) { create(:user, email: "other@example.com") }
    let!(:other_order) { create(:order, user: other_user, ticket_batch: batch1, quantity: 1, status: "paid", total_price: 50) }

    it "returns all orders for a specific user without authentication" do
      get "/api/v1/users/#{test_user.id}/orders"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].size).to eq(2)
    end

    it "returns only orders for the specified user" do
      get "/api/v1/users/#{test_user.id}/orders"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)

      order_ids = json["data"].map { |o| o["id"].to_i }
      expect(order_ids).to contain_exactly(order1.id, order2.id)
      expect(order_ids).not_to include(other_order.id)
    end

    it "returns orders in JSON:API format" do
      get "/api/v1/users/#{test_user.id}/orders"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)

      first_order = json["data"].first
      expect(first_order).to have_key("id")
      expect(first_order).to have_key("type")
      expect(first_order).to have_key("attributes")
      expect(first_order["type"]).to eq("order")
    end

    it "includes expected order attributes" do
      get "/api/v1/users/#{test_user.id}/orders"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)

      order_data = json["data"].find { |o| o["id"] == order1.id.to_s }
      attributes = order_data["attributes"]

      expect(attributes).to have_key("id")
      expect(attributes).to have_key("status")
      expect(attributes).to have_key("total_price")
      expect(attributes).to have_key("created_at")
      expect(attributes).to have_key("quantity")
      expect(attributes["status"]).to eq("paid")
      expect(attributes["total_price"].to_f).to eq(100.0)
      expect(attributes["quantity"]).to eq(2)
    end

    it "includes order relationships" do
      get "/api/v1/users/#{test_user.id}/orders"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)

      first_order = json["data"].first
      expect(first_order).to have_key("relationships")
      expect(first_order["relationships"]).to have_key("user")
      expect(first_order["relationships"]).to have_key("ticket_batch")
      expect(first_order["relationships"]).to have_key("tickets")
    end

    it "returns 404 when user not found" do
      get "/api/v1/users/999999/orders"
      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("User not found")
    end

    it "returns empty array when user has no orders" do
      user_without_orders = create(:user, email: "noorders@example.com")
      get "/api/v1/users/#{user_without_orders.id}/orders"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"]).to be_empty
    end
  end
end
