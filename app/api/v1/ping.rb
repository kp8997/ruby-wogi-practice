module V1
  class Ping < Grape::API
    desc 'Simple ping health-check endpoint'
    get :ping do
      { ping: 'pong', timestamp: Time.current.iso8601 }
    end
  end
end
