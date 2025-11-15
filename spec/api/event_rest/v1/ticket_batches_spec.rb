# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TicketBatches API", type: :request do
  let(:password) { "password123" }
  let(:admin) { create(:user, email: "admin@example.com", password: password, admin: true) }
  let(:user) { create(:user, email: "user@example.com", password: password, admin: false) }
  let(:admin_token) { JWT.encode({ user_id: admin.id }, Rails.application.credentials.secret_key_base) }
  let(:user_token) { JWT.encode({ user_id: user.id }, Rails.application.credentials.secret_key_base) }

  let!(:event) { create(:event, date: 2.weeks.from_now, category: "music") }

  describe "GET /api/v1/events/:event_id/ticket_batches" do
    let!(:available1) { create(:ticket_batch, :available_now, event: event, price: 50) }
    let!(:available2) { create(:ticket_batch, :available_now, event: event, price: 60, sale_start: 1.day.ago, sale_end: 3.days.from_now) }
    let!(:sold_out)   { create(:ticket_batch, :sold_out_now, event: event, price: 40) }
    let!(:expired)    { create(:ticket_batch, :expired, event: event, price: 30) }
    let!(:inactive)   { create(:ticket_batch, :inactive, event: event, price: 70) }

    it "returns available batches by default (asc by sale_start)" do
      get "/api/v1/events/#{event.id}/ticket_batches"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      names = json["data"].map { |d| d["id"].to_i }
      expect(names).to contain_exactly(available1.id, available2.id)
      # asc: earlier sale_start first
      expect(names.first).to eq(available1.id)
    end

    it "filters by state=sold_out" do
      get "/api/v1/events/#{event.id}/ticket_batches", params: { state: "sold_out" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |d| d["id"].to_i }
      expect(ids).to contain_exactly(sold_out.id)
    end

    it "filters by state=expired" do
      get "/api/v1/events/#{event.id}/ticket_batches", params: { state: "expired" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |d| d["id"].to_i }
      expect(ids).to contain_exactly(expired.id)
    end

    it "filters by state=inactive" do
      get "/api/v1/events/#{event.id}/ticket_batches", params: { state: "inactive" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |d| d["id"].to_i }
      expect(ids).to contain_exactly(inactive.id)
    end

    it "supports order=desc" do
      get "/api/v1/events/#{event.id}/ticket_batches", params: { state: "available", order: "desc" }
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      ids = json["data"].map { |d| d["id"].to_i }
      # desc: later sale_start first
      expect(ids.first).to eq(available2.id)
    end

    context "serialization" do
      it "includes event in the response" do
        get "/api/v1/events/#{event.id}/ticket_batches"
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)

        json["data"].each do |batch_data|
          expect(batch_data["relationships"]).to have_key("event")
          expect(batch_data["relationships"]["event"]["data"]["id"]).to eq(event.id.to_s)
        end

        included_event = json["included"]&.find { |i| i["type"] == "event" && i["id"] == event.id.to_s }
        expect(included_event).not_to be_nil
        expect(included_event["attributes"]["name"]).to eq(event.name)
      end
    end
  end

  describe "GET /api/v1/ticket_batches/:id" do
    let!(:batch) do
      TicketBatch.create!(
        event: event, available_tickets: 10, price: 50,
        sale_start: 1.day.ago, sale_end: 2.days.from_now
      )
    end

    it "returns ticket batch details" do
      get "/api/v1/ticket_batches/#{batch.id}"
      expect(response).to have_http_status(200)
      json = JSON.parse(response.body)
      expect(json["data"]["id"].to_i).to eq(batch.id)
    end

    it "returns 404 when not found" do
      get "/api/v1/ticket_batches/999999"
      expect(response).to have_http_status(404)
    end

    context "serialization" do
      it "includes event in the response" do
        get "/api/v1/ticket_batches/#{batch.id}"
        expect(response).to have_http_status(200)
        json = JSON.parse(response.body)

        expect(json["data"]["relationships"]).to have_key("event")
        expect(json["data"]["relationships"]["event"]["data"]["id"]).to eq(event.id.to_s)

        included_event = json["included"]&.find { |i| i["type"] == "event" }
        expect(included_event).not_to be_nil
        expect(included_event["id"]).to eq(event.id.to_s)
        expect(included_event["attributes"]).to have_key("name")
      end
    end
  end

  describe "POST /api/v1/events/:event_id/ticket_batches (admin only)" do
    let(:valid_params) do
      {
        available_tickets: 100,
        price: "99.99",
        sale_start: 2.days.from_now,
        sale_end: 5.days.from_now
      }
    end

    it "creates batch when admin" do
      expect {
        post "/api/v1/events/#{event.id}/ticket_batches",
             params: valid_params,
             headers: {
               "Authorization" => "Bearer #{admin_token}",
               "Content-Type" => "application/json",
               "Accept" => "application/json"
             },
             as: :json
      }.to change(TicketBatch, :count).by(1)
      expect(response).to have_http_status(201)
    end

    it "returns 403 for non-admin" do
      post "/api/v1/events/#{event.id}/ticket_batches",
           params: valid_params,
           headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(403)
    end

    it "returns 401 when unauthorized" do
      post "/api/v1/events/#{event.id}/ticket_batches", params: valid_params
      expect(response).to have_http_status(401)
    end

    it "returns 422 when dates invalid (end before start)" do
      invalid = valid_params.merge(sale_end: 1.day.from_now.iso8601, sale_start: 3.days.from_now.iso8601)
      post "/api/v1/events/#{event.id}/ticket_batches",
           params: invalid,
           headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(422)
    end

    it "returns 422 when period overlaps existing batch" do
      TicketBatch.create!(
        event: event, available_tickets: 10, price: 50,
        sale_start: 2.days.from_now, sale_end: 6.days.from_now
      )
      post "/api/v1/events/#{event.id}/ticket_batches",
           params: valid_params,
           headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(422)
    end
  end

  describe "PUT /api/v1/ticket_batches/:id (admin only)" do
    let!(:batch) do
      create(:ticket_batch, event: event, available_tickets: 50, price: 100,
                            sale_start: 2.days.from_now, sale_end: 6.days.from_now)
    end
    let(:update_params) { { price: "120.50", available_tickets: 60 } }

    it "updates batch when admin" do
      put "/api/v1/ticket_batches/#{batch.id}",
          params: update_params,
          headers: {
            "Authorization" => "Bearer #{admin_token}",
            "Content-Type" => "application/json",
            "Accept" => "application/json"
          },
          as: :json
      expect(response).to have_http_status(200), "Body: #{response.body}"
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["price"].to_s).to include("120.5")
      expect(batch.reload.price.to_s).to include("120.5")
    end

    it "returns 422 on invalid period (end before start)" do
      invalid = { sale_start: 5.days.from_now, sale_end: 3.days.from_now }
      put "/api/v1/ticket_batches/#{batch.id}",
          params: invalid,
          headers: {
            "Authorization" => "Bearer #{admin_token}",
            "Content-Type" => "application/json",
            "Accept" => "application/json"
          },
          as: :json
      expect(response).to have_http_status(422)
    end

    it "returns 403 for non-admin" do
      put "/api/v1/ticket_batches/#{batch.id}",
          params: update_params,
          headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(403)
    end

    it "returns 404 when not found" do
      put "/api/v1/ticket_batches/999999",
          params: update_params,
          headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(404)
    end
  end

  describe "DELETE /api/v1/ticket_batches/:id (admin only)" do
    let!(:batch) do
      TicketBatch.create!(
        event: event, available_tickets: 10, price: 50,
        sale_start: 1.day.from_now, sale_end: 2.days.from_now
      )
    end

    it "deletes batch when admin" do
      expect {
        delete "/api/v1/ticket_batches/#{batch.id}",
               headers: { "Authorization" => "Bearer #{admin_token}" }
      }.to change(TicketBatch, :count).by(-1)
      expect(response).to have_http_status(204)
      expect(response.body).to eq("")
    end

    it "returns 403 for non-admin" do
      delete "/api/v1/ticket_batches/#{batch.id}",
             headers: { "Authorization" => "Bearer #{user_token}" }
      expect(response).to have_http_status(403)
    end

    it "returns 404 when not found" do
      delete "/api/v1/ticket_batches/999999",
             headers: { "Authorization" => "Bearer #{admin_token}" }
      expect(response).to have_http_status(404)
    end

    it "returns 401 when unauthorized" do
      delete "/api/v1/ticket_batches/#{batch.id}"
      expect(response).to have_http_status(401)
    end
  end
end
