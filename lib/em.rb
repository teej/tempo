require "rubygems"
require "bundler/setup"
require 'eventmachine'
require 'em-imap'
require 'gmail_xoauth'
require 'gmail'
require 'em-synchrony'
require 'em-websocket'

load 'app/models/sender.rb'

EM.synchrony do
  
  EM::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
    
    ws.onopen    { ws.send "Authenticating..." }
    ws.onclose   { }
    ws.onmessage do |msg|
      Fiber.new do
        email, oauth = msg.split(":")
        @gmail = Gmail.new(email, oauth)
        @gmail.peek = true
        if @gmail.login
          ws.send "Done"
          
          @daily_email_count = {}
          
          i = 0
          Date.today.downto(Date.parse("2012-12-23")) do |date|
            EM.add_timer(3*i) do
              Fiber.new do
                ws.send "calendar_tick##{(Date.today - date).to_i}:1"
                email_senders_for_date(ws, date)
              end.resume
            end
            i += 1
          end
          
        else
          ws.send "signout#"
        end
      end.resume
    end
    
    def email_senders_for_date(ws, date)
      relative_week = ((Date.today - date).to_i + date.wday) / 7
      i = 0
      @gmail.inbox.emails(:on => date).each do |email|
        EM.add_timer(0.1*i) do
          Fiber.new do
            from_domain = sender_for_email(email)
            ws.send "email_tick##{from_domain}:#{relative_week}:#{date.wday}"
            @daily_email_count[date.to_s] -= 1
            if (@daily_email_count[date.to_s] == 0)
              ws.send "calendar_tick##{(Date.today - date).to_i}:2"
            end
          end.resume
        end
        i += 1
      end
      @daily_email_count[date.to_s] = i
    end
    
    def sender_for_email(email)
      email.from.first.split("@").last.split(".")[-2..-1].join(".")
    end
  end
end