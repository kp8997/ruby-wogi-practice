# frozen_string_literal: true

module ApiHelpers
  def json_response
    JSON.parse(response.body).with_indifferent_access
  end

  def auth_headers(user)
    token = JsonWebToken.encode(user_id: user.id, role: user.role)
    { "Authorization" => "Bearer #{token}" }
  end
end
