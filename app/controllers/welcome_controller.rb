class WelcomeController < ApplicationController
  def index
    puts session[:oauth]
  end
end
