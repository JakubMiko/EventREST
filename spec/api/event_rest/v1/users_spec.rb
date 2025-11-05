# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users API", type: :request do
  let(:password) { "password123" }
  let(:user) { create(:user, password: password, password_confirmation: password, email: "test@example.com") }
  let(:admin) { create(:user, password: password, password_confirmation: password, email: "admin@example.com", admin: true) }
  let(:token) { JWT.encode({ user_id: user.id }, Rails.application.credentials.secret_key_base) }
  let(:admin_token) { JWT.encode({ user_id: admin.id }, Rails.application.credentials.secret_key_base) }

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
end
