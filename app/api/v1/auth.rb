module V1
  class Auth < Grape::API
    resource :auth do
      desc 'User login endpoint with param validations'
      params do
        requires :email, type: String, regexp: /.+@.+/, desc: 'Valid user email'
        requires :password, type: String, desc: 'User password'
      end
      post :login do
        # Simulated authentication response
        {
          status: 'success',
          user: { email: params[:email] },
          token: 'sample-jwt-token-xyz'
        }
      end
    end
  end
end
