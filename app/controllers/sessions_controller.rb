class SessionsController < ApplicationController
  def create
    auth = request.env["omniauth.auth"]
    session[:oauth] = auth.credentials.token
    session[:email] = auth.info.email
    redirect_to sonata_url
  end

  def destroy
    session[:oauth] = nil
    session[:email] = nil
    redirect_to root_url, :notice => "Signed out!"
  end
end