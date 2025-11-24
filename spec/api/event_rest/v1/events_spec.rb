# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Events API", type: :request do
  let(:password) { "password123" }
  let(:admin) { create(:user, email: "admin@example.com", password: password, admin: true) }
  let(:user) { create(:user, email: "user@example.com", password: password, admin: false) }
  let(:admin_token) { JWT.encode({ user_id: admin.id }, Rails.application.secret_key_base) }
  let(:user_token) { JWT.encode({ user_id: user.id }, Rails.application.secret_key_base) }

  describe "GET /api/v1/events" do
    let!(:event1) { create(:event, name: "Concert", category: "music", date: 1.week.from_now) }
    let!(:event2) { create(:event, name: "Workshop", category: "sports", date: 2.weeks.from_now) }
    let!(:past_event) { create(:event, name: "Past Event", category: "music", date: 1.week.ago) }

    it "returns all events" do
      get "/api/v1/events"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(3)
    end

    it "filters events by category" do
      get "/api/v1/events", params: { category: "music" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(2)
      expect(json["data"].map { |e| e["attributes"]["name"] }).to contain_exactly("Concert", "Past Event")
    end

    it "returns only upcoming events" do
      get "/api/v1/events", params: { upcoming: true }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(2)
      expect(json["data"].map { |e| e["attributes"]["name"] }).to contain_exactly("Concert", "Workshop")
    end

    it "returns only past events" do
      get "/api/v1/events", params: { past: true }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"].size).to eq(1)
      expect(json["data"].first["attributes"]["name"]).to eq("Past Event")
    end

    context "serialization" do
      let!(:event_with_batches) { create(:event, name: "Event with batches") }
      let!(:batch1) { create(:ticket_batch, event: event_with_batches, price: 50) }
      let!(:batch2) { create(:ticket_batch, event: event_with_batches, price: 100) }

      it "does not include ticket_batches in index response (requires separate request)" do
        get "/api/v1/events"
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)

        # ticket_batches should not be included in the index response
        expect(json["included"]).to be_nil
      end
    end
  end

  describe "GET /api/v1/events/:id" do
    let!(:event) { create(:event, name: "Test Event") }

    it "returns event details" do
      get "/api/v1/events/#{event.id}"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["name"]).to eq("Test Event")
    end

    it "returns 404 if event not found" do
      get "/api/v1/events/99999"
      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Event not found")
    end

    context "serialization" do
      let!(:event_with_batches) { create(:event, name: "Event with batches") }
      let!(:batch1) { create(:ticket_batch, event: event_with_batches, price: 75) }
      let!(:batch2) { create(:ticket_batch, event: event_with_batches, price: 150) }
      let!(:batch3) { create(:ticket_batch, event: event_with_batches, price: 200) }

      it "includes all ticket_batches in the response" do
        get "/api/v1/events/#{event_with_batches.id}"
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)

        expect(json["data"]["relationships"]).to have_key("ticket_batches")
        expect(json["data"]["relationships"]["ticket_batches"]["data"].size).to eq(3)

        batch_ids = json["data"]["relationships"]["ticket_batches"]["data"].map { |b| b["id"] }
        included_batches = json["included"].select { |i| i["type"] == "ticket_batch" }
        expect(included_batches.size).to eq(3)
        expect(included_batches.map { |b| b["attributes"]["price"].to_f }).to contain_exactly(75.0, 150.0, 200.0)
      end
    end
  end

  describe "POST /api/v1/events (admin only)" do
    let(:valid_params) do
      {
        name: "New Event",
        description: "Event description",
        place: "Warsaw",
        date: 1.week.from_now.iso8601,
        category: "music"
      }
    end

    it "creates event when admin" do
      post "/api/v1/events", params: valid_params, headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(201)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["name"]).to eq("New Event")
      expect(Event.count).to eq(1)
    end

    it "returns 403 when non-admin tries to create event" do
      post "/api/v1/events", params: valid_params, headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(403)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Forbidden")
    end

    it "returns 401 when unauthorized" do
      post "/api/v1/events", params: valid_params
      expect(response).to have_http_status(401)
    end

    it "returns 422 with validation errors" do
      invalid_params = valid_params.merge(date: 1.week.ago.iso8601)
      post "/api/v1/events", params: invalid_params, headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)
      expect(json["error"]).to include("future")
    end

    it "returns 422 when required params missing" do
      post "/api/v1/events", params: { name: "Test" }, headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(422)
    end
  end

  describe "PUT /api/v1/events/:id (admin only)" do
    let!(:event) do
      create(
        :event,
        name: "Old Name",
        description: "Old desc",
        place: "Warsaw",
        category: "music",
        date: 1.week.from_now
      )
    end
    let(:update_params) do
      {
        name: "Updated Name",
        description: "Updated description"
      }
    end

    it "updates event when admin" do
      put "/api/v1/events/#{event.id}", params: update_params, headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["name"]).to eq("Updated Name")
      expect(event.reload.name).to eq("Updated Name")
    end

    it "returns 403 when non-admin tries to update" do
      put "/api/v1/events/#{event.id}", params: update_params, headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(403)
    end

    it "returns 404 when event not found" do
      put "/api/v1/events/99999", params: update_params, headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Event not found")
    end

    it "returns 422 with validation errors" do
      invalid_params = { date: 1.week.ago.iso8601 }
      put "/api/v1/events/#{event.id}", params: invalid_params, headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(422)
    end

    it "returns 401 when unauthorized" do
      put "/api/v1/events/#{event.id}", params: update_params
      expect(response).to have_http_status(401)
    end
  end

  describe "DELETE /api/v1/events/:id (admin only)" do
    let!(:event) { create(:event) }

    it "deletes event when admin" do
      expect {
        delete "/api/v1/events/#{event.id}", headers: { "Authorization" => "Bearer #{admin_token}" }
      }.to change(Event, :count).by(-1)
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Event deleted")
    end

    it "returns 403 when non-admin tries to delete" do
      delete "/api/v1/events/#{event.id}", headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(403)
      expect(Event.count).to eq(1)
    end

    it "returns 404 when event not found" do
      delete "/api/v1/events/99999", headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(404)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Event not found")
    end

    it "returns 401 when unauthorized" do
      delete "/api/v1/events/#{event.id}"
      expect(response).to have_http_status(401)
    end
  end
end
