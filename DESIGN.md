Link Excalidraw for details: https://excalidraw.com/#json=G8pbshRMjyxCJiJldNZm8,U04XEYfEBLRVtaV3kWyE0w

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
