require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get dashboard_url
    assert_response :redirect
  end

  test "shows own dashboard when authenticated" do
    user = User.create!(email: "user@example.com", password: "password123", password_confirmation: "password123")
    sign_in user

    get dashboard_url
    assert_response :success
  end

  test "blocks access to other user's dashboard" do
    user = User.create!(email: "user1@example.com", password: "password123", password_confirmation: "password123")
    other = User.create!(email: "user2@example.com", password: "password123", password_confirmation: "password123")
    sign_in user

    # rota por usuário não existe mais: o dashboard é sempre do current_user
    assert_raises(ActionController::UrlGenerationError) { user_dashboard_url(other) }
  end
end
