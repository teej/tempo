module EmailHelper
  def websocket_session
    "#{session[:email]}:#{session[:oauth]}".html_safe
  end
end
