# frozen_string_literal: true

module EventRest
  module V1
    class Users < Grape::API
      resource :users do
        desc "Get all users (for benchmark testing)" do
          success code: 200, message: "Returns a list of all users"
        end
        get do
          users = User.limit(10)
          UserSerializer.new(users).serializable_hash
        end

        desc "Register a new user" do
          success code: 201, message: "Returns JWT + user data"
          failure [ { code: 422, message: "Validation failed" } ]
        end
        params do
          requires :first_name, type: String
          requires :last_name, type: String
          requires :email, type: String
          requires :password, type: String
          requires :password_confirmation, type: String
        end
        post :register do
          declared_params = declared(params, include_missing: false)
          user = User.new(declared_params)
          if user.save
            token = JWT.encode({ user_id: user.id }, Rails.application.secret_key_base)
            status 201
            { token:, data: UserSerializer.new(user).serializable_hash }
          else
            raise EventRest::V1::Base::ApiException.new(user.errors.full_messages.join(", "), 422)
          end
        end

        desc "Log in user" do
          success code: 200,
                  message: "Returns JWT token and user data"
        end
        params do
          requires :email, type: String
          requires :password, type: String
        end
        post :login do
          declared_params = declared(params, include_missing: false)
          user = User.find_by(email: declared_params[:email])
          unless user&.valid_password?(declared_params[:password])
            raise EventRest::V1::Base::ApiException.new("Invalid email or password", 401)
          end
          token = JWT.encode({ user_id: user.id }, Rails.application.secret_key_base)
          status 200
          { token:, data: UserSerializer.new(user).serializable_hash }
        end

        desc "Get current logged-in user data" do
          success code: 200,
                  message: "Returns current logged-in user data"
        end
        get :current do
          authorize!
          user = current_user
          UserSerializer.new(user).serializable_hash
        end

        desc "Get public user profile by id" do
          success code: 200,
                  message: "Returns public user profile data"
        end
        params do
          requires :id, type: Integer
        end
        get "public/:id" do
          user = User.find_by(id: params[:id])
          raise EventRest::V1::Base::ApiException.new("User not found", 404) unless user
          PublicUserSerializer.new(user).serializable_hash
        end

        desc "Get full user data by id (admin only)" do
          success code: 200,
                  message: "Returns full user data"
        end
        params do
          requires :id, type: Integer
        end
        get ":id" do
          admin_only!
          user = User.find_by(id: params[:id])
          raise EventRest::V1::Base::ApiException.new("User not found", 404) unless user
          UserSerializer.new(user).serializable_hash
        end

        desc "Get all orders for a specific user (for benchmark testing)" do
          success code: 200, message: "Returns all orders for the specified user"
          failure [ { code: 404, message: "User not found" } ]
        end
        params do
          requires :id, type: Integer
        end
        get ":id/orders" do
          user = User.find_by(id: params[:id])
          raise EventRest::V1::Base::ApiException.new("User not found", 404) unless user
          orders = user.orders.order(created_at: :desc)
          OrderListSerializer.new(orders).serializable_hash
        end

        desc "Change password for logged-in user" do
          success code: 200,
                  message: "Password changed successfully"
        end
        params do
          requires :current_password, type: String
          requires :password, type: String
          requires :password_confirmation, type: String
        end
        put :change_password do
          authorize!
          declared_params = declared(params, include_missing: false)
          user = current_user
          unless user.valid_password?(declared_params[:current_password])
            raise EventRest::V1::Base::ApiException.new("Current password is incorrect", 422)
          end
          if declared_params[:password] != declared_params[:password_confirmation]
            raise EventRest::V1::Base::ApiException.new("Password confirmation does not match", 422)
          end
          if user.update(password: declared_params[:password], password_confirmation: declared_params[:password_confirmation])
            { message: "Password changed successfully" }
          else
            raise EventRest::V1::Base::ApiException.new(user.errors.full_messages.join(", "), 422)
          end
        end
      end
    end
  end
end
