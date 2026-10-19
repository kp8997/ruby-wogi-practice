# README

This README would normally document whatever steps are necessary to get the
application up and running.

Some specific external dependencies

  GrapeAPI

  Rspec

Some configuration detail about project

* Ruby version

  3.4.11

* System dependencies

  rbenv
  rbenv-build
  postgresql
  rails 7.2.5
  bundler 3.3.5

* Configuration

* Database creation

  bin/rails db:create

* Database initialization

  bin/rails db:migrate
  bin/rails db:seed

* How to run the test suite

  bundle exec rspec

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* Support

  /postman: create importing file for all api along with data, authentication information to quickly test it

* ...

# HOW TO START PROJECT

### Option 1: Docker Compose (Recommended)

No local Ruby, Bundler, or PostgreSQL installation required. All dependencies and database services run containerized.

1. **(Optional) Configure environment ports:**
   If you have local services running on port 3000 or 5432, customize host ports by copying `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   # Edit APP_PORT or DB_PORT if needed (e.g., APP_PORT=3002 DB_PORT=5434)
   ```

2. **Build and start the application:**
   ```bash
   docker compose up --build
   ```
   > **Note:** The container entrypoint automatically waits for PostgreSQL readiness, clears any stale server PID, and runs `bundle exec rails db:prepare` (creating the database and running migrations/seeds).

3. **Verify API is running:**
   ```bash
   curl http://localhost:3000/api/v1/ping
   # Expected response: {"ping":"pong", ...}
   ```

4. **Initialize sample test data (Admin, Client, Catalog, Cards):**
   ```bash
   docker compose exec web ./bin/init_api_data.sh
   # Or run from host: API_BASE_URL=http://localhost:3000/api/v1 ./bin/init_api_data.sh
   ```

5. **Run test suite (RSpec):**
   ```bash
   docker compose exec -e RAILS_ENV=test web bundle exec rspec
   ```

6. **Useful Docker commands:**
   - **Interactive Rails Console:**
     ```bash
     docker compose exec web bin/rails console
     ```
   - **Run Migrations:**
     ```bash
     docker compose exec web bin/rails db:migrate
     ```
   - **Reset Database:**
     ```bash
     docker compose exec web bin/rails db:reset
     ```
   - **Stop Services:**
     ```bash
     docker compose down
     # Or to wipe volumes/database:
     docker compose down -v
     ```

---

### Option 2: Manual Local Setup

Requires local Ruby `3.4.11` and running PostgreSQL service:

1. **Install gems:**
   ```bash
   bundle install
   ```

2. **Setup database:**
   ```bash
   bin/rails db:create db:migrate db:seed
   ```

3. **Start Rails server:**
   ```bash
   bin/rails server
   ```

4. **Run test suite:**
   ```bash
   bundle exec rspec
   ```

---

# DESIGN & IMPLEMENTATION STRATEGIES
This is my working space from requirement to breakdown into relevant thing of system design and flow to achieve the final working API.

Link Excalidraw for details:
  v1: https://excalidraw.com/#json=G8pbshRMjyxCJiJldNZm8,U04XEYfEBLRVtaV3kWyE0w

  v2: https://excalidraw.com/#json=nfxh5JExjir9jOqFAwFLa,TPHVUdGodrp_sVGQzGmJOw

  v3: https://excalidraw.com/#json=KeLUos_g35wsSBnCmPkpC,wIpI_OKZBravS53lRvW77g

  v4: https://excalidraw.com/#json=fYO_SU0Q_kpRLrfK3znVf,TOuve_cAfWPMxjbI8CLP1A

  v5: https://excalidraw.com/#json=uR3CZ1YzpEU2Am5SZtJ7q,nK_w4PE2qGXQ5y8UOYM25Q

Implementation Strategies
  
  1. Design database from the requirements.

    1.1 List out entities first:
    
    1.2 Draw relationships between tables.

    1.3 Define schema for each tables: constraint, index base on relationship above

    1.4 Define model essential functions & validation (when and how to use later in API)

  2. Design endpoint for API
    
    2.1 List out endpoints needed from the requirements along with method (GET/POST/PUT/DELETE) and basic description

    2.2 Group endpoints base on the auth group for better route
    
    2.3 Design request & response format for each endpoint
    
    2.4 Design validation for each endpoint
  
  3. Write code to implement for API

  4. Write rspec for each test case from API (step 2) and then model (step 1)

  5. Review some edge cases if needed

  6. Any performance optimization in coding / database query if needed

  7. dockerize, make docker-compose.yml for database and rails

    - add rails environment variable for production & development

    - add secrets.yml for production env
    
    - CI/CD if needed and have time

  8. (Optional) Define UI to test out those feature


# PROGRESS

## DAY 1

Initialize project

Clean up unneccessary file

Add some base library (grape api)

Implement base API structure to test like helloworld

Design database Schema for authentication & authorization with tables: around 3 attributes and some auto validation:

Design implementation strategies with handwritten and draw (excalidraw.com) and save link in the README.md

## DAY 2

Design database Schema for brands, product, clients and products permission, audit_logs

Add function for brands, clients and products in model

Test on data with model - via rails console

Define Seeds for convenient

## DAY 3

API implementation for users, clients

API implementation for brands, product, clients and products permission

API implementation for audit_logs

Verify by manual test

## DAY 4

Add Rspec for Models and API

Dockerize and containerize

Verify by manual test for container

Deployment

CI/CD

## DAY 5

Prepare Postman importing files

Optional: make UI to test it

Send to the hiring team
