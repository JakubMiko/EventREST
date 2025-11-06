# EventREST

EventREST is a RESTful API for managing events and selling tickets. It was built as part of a master's thesis to be compared against an equivalent GraphQL implementation (same domain and features) in terms of ergonomics, performance, and implementation complexity.

## Tech Stack

- Ruby 3.4.7
- Rails 8 (API mode)
- Grape 2.4 (API endpoints)
- Devise (authentication base)
- JWT (Bearer token auth)
- PostgreSQL
- RSpec (tests)
- grape-swagger + grape-swagger-rails (OpenAPI documentation)
- json-api

## Core Features

- Events: list, details, admin CRUD
- Ticket Batches: time‑bound ticket pools with pricing and quantity (admin CRUD)
- Orders: place order, pay (mock), cancel, list own; admin sees all
- Tickets: list own tickets, view ticket
- Users: register, login (JWT), current profile, password handling
- Roles: regular user vs admin (extra management rights)

## Requirements

- PostgreSQL
- Ruby 3.4.7
- Bundler

## Setup

1. Clone repo
   git clone <repo_url>
   cd EventREST

3. Install gems
   bundle install

4. Database
   Ensure PostgreSQL is running
   bin/rails db:prepare

5. Credentials (for JWT secret)
   bin/rails credentials:edit
   Ensure config/master.key exists or set RAILS_MASTER_KEY

6. Run server
   bin/rails s
   API base: http://localhost:3000

## Documentation

- Swagger UI: http://localhost:3000/api/docs
- OpenAPI JSON: http://localhost:3000/api/v1/swagger_doc
- Health: GET /api/v1/ping

## Tests

Run:
bundle exec rspec

## Purpose

This REST implementation serves as the baseline for a comparative study against a GraphQL version covering the same functional scope.
