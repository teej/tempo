class EmailController < ApplicationController
  
  def read
    
    # gmail = Gmail.new("teej.murphy@gmail.com", session[:oauth])
    # gmail.peek = true
    # 
    # @emails = {}
    # gmail.inbox.emails(:after => Date.parse("2012-12-26")).each do |email|
    #   
    #   sender_name = sender_for_email(email)
    #   
    #   @emails[sender_name] = Sender.new(sender_name) unless @emails[sender_name]
    #   @emails[sender_name] << email.date
    #   
    # end
    # gmail.logout
    
  end
  
  
  def sender_for_email(email)
    email.from.first.split("@").last.split(".")[-2..-1].join(".")
  end
end
