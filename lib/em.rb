require "rubygems"
require "bundler/setup"
require 'eventmachine'
require 'em-imap'
require 'gmail_xoauth'
require 'gmail'
require 'em-synchrony'
require 'em-websocket'
require 'logger'
require 'domainatrix'

load 'app/models/sender.rb'
module EventMachine
  module WebSocket
    class Connection
      
      def identify
        @@connections[self.object_id] ||= {}
      end
      
      def conn
        @@connections[self.object_id]
      end
      
      def logout
        Fiber.new do
          if conn[:gmail] && conn[:gmail].logged_in?
            conn[:gmail].logout
            conn = nil
          end
        end.resume
      end

      def gmail
        return conn[:gmail] if conn[:gmail] && conn[:gmail].logged_in?
        conn[:gmail] = Gmail.new(conn[:email], conn[:oauth])
        conn[:gmail].peek = true
        conn[:gmail].login
        conn[:gmail]
      end
      
      def email_senders_for_date(date)
        weeks_ago = ((Date.today - date).to_i + date.wday) / 7
        i = 0
        conn[:daily_email_count][date.to_s] = gmail.inbox.count(:on => date)
        gmail.inbox.emails(:on => date).each do |email|
          EM.add_timer(0.3*i) do
            
            return unless conn
            
            Fiber.new do
              sender_tld = extract_sender_tld(email)
              send "email_tick##{sender_tld}:#{weeks_ago}:#{date.wday}"
              conn[:daily_email_count][date.to_s] -= 1
              if (conn[:daily_email_count][date.to_s] == 0)
                send "calendar_tick##{(Date.today - date).to_i}:2"
              end
            end.resume
          end
          i += 1
        end
      end
      
      def extract_sender_tld(email)
        sender_tld = email.from # Get the "From:" email address from the header
        sender_tld = sender_tld.split("@").last
        sender_tld = Domainatrix.parse(sender_tld)
        sender_tld.domain + "." + sender_tld.public_suffix
      end
    end
  end
end

EM.synchrony do
  
  EM::WebSocket.start(:host => "0.0.0.0", :port => 8080) do |ws|
    
    @@log = Logger.new(File.expand_path('~/tempo_server.log'), 'daily')
    @@log.level = Logger::INFO
    @@connections ||= {}
    
    ws.onopen    { ws.send "Authenticating..." }
    ws.onclose   { ws.logout }
    
    ws.onerror   do |err|
      puts err.inspect, err.backtrace
      @@log.error "-- error: [#{err.inspect}]"
      @@log.error err.backtrace
      ws.close_websocket
    end
    
    ws.onmessage do |msg|
      
      ws.identify
        
      header, msg = msg.split("#")
    
      if header == "login"
        Fiber.new do
          ws.conn[:email], ws.conn[:oauth] = msg.split(":")
          _gmail = Gmail.new(ws.conn[:email], ws.conn[:oauth])
          _gmail.login
          if _gmail.logged_in?
            ws.send "Done"
            @@log.info "New user authorized: #{ws.conn[:email][0..4]}"
          else
            ws.send "signout#"
          end
          _gmail.logout
        end.resume
      elsif header == "get_tick"
        date_to_check = Date.today - msg.to_i
        ws.conn[:daily_email_count] ||= {}
        Fiber.new do
          ws.send "calendar_tick##{msg}:1"
          ws.email_senders_for_date(date_to_check)
        end.resume
      end
    end
  end
end