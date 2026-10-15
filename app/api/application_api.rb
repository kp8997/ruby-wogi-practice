class ApplicationApi < Grape::API
  format :json # res and req will be in json format
  prefix :api # All api endpoints will start with /api

  # Mount API versions
  mount V1::Base # map api/v1/base.rb file to rails route
end
