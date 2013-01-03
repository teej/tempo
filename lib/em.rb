require "rubygems"
require "bundler/setup"
require 'eventmachine'
require 'em-imap'
require 'gmail_xoauth'
require 'gmail'
require 'em-synchrony'
require 'em-websocket'
require 'logger'

load 'app/models/sender.rb'

EM.synchrony do
  
  EM::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
    
    @@log = Logger.new(File.expand_path('~/tempo_server.log'), 'daily')
    @@log.level = Logger::INFO
    
    ws.onopen    { ws.send "Authenticating..." }
    ws.onclose   { conn = nil }
    ws.onerror   { ws.close_websocket }
    ws.onmessage do |msg|
      
      @@connections ||= {}
      @@connections[ws.object_id] ||= {}
      
      begin
        
        header, msg = msg.split("#")
      
        if header == "login"
          Fiber.new do
          
            conn[:email], conn[:oauth] = msg.split(":")
            _gmail = Gmail.new(conn[:email], conn[:oauth])
            _gmail.login
            if _gmail.logged_in?
              ws.send "Done"
              @@log.info "New user authorized: #{conn[:email][0..5]}"
            else
              ws.send "signout#"
            end
            _gmail.logout
          end.resume
        elsif header == "get_tick"
          date = Date.today - msg.to_i
          @daily_email_count ||= {}
          Fiber.new do
            ws.send "calendar_tick##{msg}:1"
            email_senders_for_date(ws, date)
          end.resume
        end
      rescue Exception => e
        @@log.error "-- error: [#{e.inspect}]"
        @@log.error e.backtrace
        ws.close_websocket
      end
    end
    
    def email_senders_for_date(ws, date)
      relative_week = ((Date.today - date).to_i + date.wday) / 7
      i = 0
      # Gmail.new(@email, @oauth) do |gmail|
        # gmail.peek = true
        
        @daily_email_count[date.to_s] = gmail(ws).inbox.count(:on => date)
        gmail(ws).inbox.emails(:on => date).each do |email|
          EM.add_timer(0.3*i) do
            Fiber.new do
              # puts email.header.inspect
              
              return unless conn
              
              from_domain = sender_for_email(email)
              ws.send "email_tick##{from_domain}:#{relative_week}:#{date.wday}"
              @daily_email_count[date.to_s] -= 1
              if (@daily_email_count[date.to_s] == 0)
                ws.send "calendar_tick##{(Date.today - date).to_i}:2"
              end
            end.resume
          end
          i += 1
        # end
      end
      
    end
    
    def sender_for_email(email)
      email.from.split("@").last.split(".")[-2..-1].join(".")
    end
    
    def conn
      @@connections[ws.object_id]
    end
    
    def gmail(ws)
      
      if conn[:gmail]
        if conn[:gmail].logged_in?
          return conn[:gmail]
        else
          conn[:gmail] = nil
        end
      end
      conn[:gmail] = Gmail.new(conn[:email], conn[:oauth])
      conn[:gmail].peek = true
      conn[:gmail].login
      conn[:gmail]
    end
  end
end