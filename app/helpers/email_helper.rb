module EmailHelper
  def websocket_session
    "login##{session[:email]}:#{session[:oauth]}".html_safe
  end
end
