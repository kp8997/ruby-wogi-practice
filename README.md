# README

This README would normally document whatever steps are necessary to get the
application up and running.

Some configuration detail about project

* Ruby version
  3.4.11

* System dependencies
  brew install ruby-build
  postgresql
  gem install rails
  gem install bundler

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

# HOW TO START PROJECT
## Initialize database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# DESIGN & IMPLEMENTATION STRATEGIES

Link Excalidraw for details:
  v1: https://excalidraw.com/#json=G8pbshRMjyxCJiJldNZm8,U04XEYfEBLRVtaV3kWyE0w

  v2: https://excalidraw.com/#json=nfxh5JExjir9jOqFAwFLa,TPHVUdGodrp_sVGQzGmJOw

  v3: https://excalidraw.com/#json=KeLUos_g35wsSBnCmPkpC,wIpI_OKZBravS53lRvW77g

  v4: https://excalidraw.com/#json=fYO_SU0Q_kpRLrfK3znVf,TOuve_cAfWPMxjbI8CLP1A
  
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
Design database Schema for authentication & authorization with tables:
  users: client/admin role
  clients client role and client information
  use has_secure_password built-in function in ActiveRecord. From the helper method it has around 3 attributes and some auto validation:
    password (non-db column): store raw string function from user input
    password_confirmation (non-db column): confirm same value with password
    password_digest (db-column): Rails automatically hashes raw string and saves as secure string
    validation: on presence, confirmation of password and maximum byte length of password (<=72)
Design implementation strategies with handwritten and draw (excalidraw.com) and save link in the DESIGN.md

## DAY 2

Design database Schema for brands, product, clients and products permission, audit_logs
Add function for brands, clients and products in model
API implementation for users, clients

## DAY 3

API implementation for brands, product, clients and products permission, audit_logs
Verify by manual test

## DAY 4

Add Rspec for Models and API
Dockerize and containerize
Verify by manual test for container
Deployment
CI/CD

## DAY 5

Optional: make UI to test it
Send to the hiring team
