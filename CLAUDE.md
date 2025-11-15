# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EventREST is a RESTful API for event management and ticket sales, built as part of a master's thesis to compare REST vs GraphQL implementations. It uses Ruby 3.4.7, Rails 8 (API mode), and Grape 2.4 for API endpoints.

**Tech Stack:**
- Ruby 3.4.7 / Rails 8 (API mode)
- Grape 2.4 (API framework)
- PostgreSQL
- Devise + JWT (authentication)
- RSpec + FactoryBot (testing)
- grape-swagger (OpenAPI docs)
- jsonapi-serializer (JSON:API format)
- dry-validation + dry-monads (validation & service objects)

## Development Commands

### Setup
```bash
bundle install
bin/rails db:prepare
bin/rails credentials:edit  # Ensure JWT secret exists
```

### Running the Server
```bash
bin/rails s
# API base: http://localhost:3000
# Swagger UI: http://localhost:3000/api/docs
# Health check: GET /api/v1/ping
```

### Testing
```bash
bundle exec rspec                          # Run all tests
bundle exec rspec spec/api/event_rest/v1/  # API specs only
bundle exec rspec spec/path/to/file_spec.rb # Single file
bundle exec rspec spec/path/to/file_spec.rb:42 # Single test at line 42
```

### Database
```bash
bin/rails db:migrate
bin/rails db:seed              # Seeds ~450MB benchmark data (deterministic)
FORCE_SEED=true bin/rails db:seed  # Force reseed in production
bin/rails db:reset             # Drop, recreate, migrate, seed
```

### Code Quality
```bash
bundle exec rubocop            # Lint (uses rubocop-rails-omakase)
bundle exec rubocop -a         # Auto-fix
bundle exec brakeman           # Security analysis
```

## Architecture

### API Structure (Grape-based)

The API is built with Grape, not standard Rails controllers. All endpoints are under `/api/v1/`:

- **Entry point:** `app/api/event_rest/api.rb` mounts the V1 base
- **Base class:** `app/api/event_rest/v1/base.rb` contains:
  - Authentication helpers (`current_user`, `authorize!`, `admin_only!`)
  - Error handling (ApiException, ValidationErrors)
  - JWT decoding logic
  - Resource mounts (Users, Events, TicketBatches, Orders, Tickets)
  - Swagger documentation config

**Resource endpoints:** Each in `app/api/event_rest/v1/`:
- `users.rb` - Registration, login (JWT), profile, password management
- `events.rb` - List (with filters), show, admin CRUD
- `ticket_batches.rb` - Time-bound ticket pools with pricing (admin CRUD)
- `orders.rb` - Place order, pay (mock), cancel, list own/all
- `tickets.rb` - List own tickets, view ticket details

### Authentication Pattern

JWT-based authentication using Devise + custom JWT logic:

1. User registers/logs in via `POST /api/v1/users/login`
2. Response includes JWT token
3. Subsequent requests include `Authorization: Bearer <token>` header
4. `current_user` helper decodes JWT using `Rails.application.credentials.secret_key_base`
5. `authorize!` raises 401 if no user, `admin_only!` raises 403 if not admin

**Important:** RSpec tests mock `Rails.application.credentials.secret_key_base` to `"test_secret_key_base_123"` (see `spec/rails_helper.rb:76-78`)

### Service Object Pattern

All business logic lives in service objects using dry-monads Result pattern:

```ruby
# app/services/[resource]/[action]_service.rb
class SomeService < ApplicationService
  include Dry::Monads[:result]  # Inherited from ApplicationService

  def call
    # Validation via Contract
    # Business logic
    Success(result) or Failure(error_message)
  end
end
```

**Example:** `Orders::CreateService` (app/services/orders/create_service.rb):
- Locks ticket batch for transaction safety
- Validates via `Orders::CreateContract`
- Creates order + decrements available_tickets atomically
- Generates individual Ticket records
- Returns `Success(order)` or `Failure(error_string)`

**Usage in Grape endpoints:**
```ruby
result = ::Events::CreateService.new(params).call
raise ApiException.new(result.failure, 422) if result.failure?
EventSerializer.new(result.value!).serializable_hash
```

### Validation Pattern (dry-validation)

Contracts in `app/contracts/[resource]/[action]_contract.rb` extend `ApplicationContract` (Dry::Validation::Contract).

**Example:** `Events::CreateContract` validates event creation params. Contracts can access injected dependencies (e.g., `ticket_batch` in `Orders::CreateContract` to validate against available tickets).

### Query Objects

Query objects in `app/queries/` encapsulate filtering/scoping logic:

- `EventsQuery` - Filters events by category, upcoming/past
- `TicketsQuery` - User's tickets with optional filters
- `TicketBatchQuery` - Ticket batch queries

**Pattern:**
```ruby
EventsQuery.new(params: params).call  # Returns ActiveRecord scope
```

### Serialization (JSON:API)

All serializers in `app/serializers/` inherit from `BaseSerializer` (includes `JSONAPI::Serializer`). They return JSON:API formatted responses.

**Pattern:**
```ruby
EventSerializer.new(event).serializable_hash
EventSerializer.new(events, include: [:ticket_batches]).serializable_hash
```

## Important Implementation Notes

### Benchmark Seeding

`db/seeds.rb` creates deterministic benchmark data for GraphQL vs REST comparison:
- 10,000 users (20 admins)
- 15,000 events (10k past, 5k future)
- ~90,000 ticket batches (6 types per event)
- ~160,000 orders
- ~400,000 tickets
- Target: ~450MB database size

**Critical:** Seeds use fixed random seeds (`Random.srand(42)`, `Faker::Config.random = Random.new(42)`) for identical data across runs.

**Test accounts:** `admin1@benchmark.test` / `password` through `admin20@benchmark.test`, `user1@benchmark.test` / `password` through `user9980@benchmark.test`

### Testing Patterns

- **Request specs** in `spec/api/event_rest/v1/` test API endpoints
- **FactoryBot** for test data (`spec/factories/`)
- **JWT mocking** happens globally in `rails_helper.rb`
- Use `create(:user)`, `create(:event)`, etc. for test data

### Domain Model

- **Event** has_many :ticket_batches, :tickets (categories: music, theater, sports, etc.)
- **TicketBatch** belongs_to :event (time-bound sales window, pricing, quantity)
- **Order** belongs_to :user, :ticket_batch (statuses: pending, paid, cancelled)
- **Ticket** belongs_to :order, :user, :event (individual ticket with unique number)
- **User** has Devise + admin boolean flag

### Order Flow

1. User places order via `POST /api/v1/orders` with ticket_batch_id + quantity
2. `Orders::CreateService` locks batch, validates, creates order + tickets atomically
3. User pays via `POST /api/v1/orders/:id/pay` (mock payment)
4. User can cancel via `POST /api/v1/orders/:id/cancel`
5. Tickets are generated immediately on order creation (not after payment)

## Configuration Notes

- **Database:** Uses PostgreSQL, can connect via Unix socket (see `config/database.yml`)
- **Credentials:** JWT secret stored in `config/credentials.yml.enc`, edit with `bin/rails credentials:edit`
- **CORS:** Enabled via rack-cors
- **Rails Mode:** API-only (no views, minimal middleware)
- **Deployment:** Kamal/Docker ready (see Dockerfile, .kamal/)
