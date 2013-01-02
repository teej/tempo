module ApplicationHelper
  def logged_in?
    session[:oauth] and session[:email]
  end
end
