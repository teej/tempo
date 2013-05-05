class WelcomeController < ApplicationController
  def index
    puts session[:oauth]
  end
  
  def learn
    @title = "Learn More"
  end
end
