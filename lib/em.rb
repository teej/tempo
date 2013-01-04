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
        
        message_uids = gmail.mailbox('[Gmail]/All Mail').emails(:on => date).map{ |msg| msg.uid }
        
        imap_request = 'BODY.PEEK[HEADER.FIELDS (FROM)]'
        data_attr    = 'BODY[HEADER.FIELDS (FROM)]'
        
        msg_headers = gmail.in_mailbox(gmail.mailbox('[Gmail]/All Mail')) do
          gmail.imap.uid_fetch(message_uids, imap_request).map{ |e| e.attr[data_attr] }
        end
        
        msg_headers.each do |from_header|
          sender_tld = extract_sender_tld(from_header)
          send "email_tick##{sender_tld}:#{weeks_ago}:#{date.wday}"
        end
        
        send "calendar_tick##{(Date.today - date).to_i}:2"
      end
      
      def extract_sender_tld(from_header)
        # A typical FROM header looks like:
        # "From: Twitter <n-grrw.zhecul=tznvy.pbz-346f4@postmaster.twitter.com>\r\n\r\n
        
        # This code gets the last token in the string with an @ symbol
        from_header = from_header.strip
        from_header = from_header.split(" ")
        sender_addr = ""
        from_header.reverse_each do |part|
          if part.include? "@"
            sender_addr = part.delete("<>").strip
            break
          end
        end
        
        # sender_addr #=> "n-grrw.zhecul=tznvy.pbz-346f4@postmaster.twitter.com"
        
        sender_tld = sender_addr.split("@").last
        sender_tld = Domainatrix.parse(sender_tld)
        sender_tld.domain + "." + sender_tld.public_suffix
      end
      
      def log(err)
        puts err.inspect, err.backtrace
        @@log.error "-- error: [#{err.inspect}]"
        @@log.error err.backtrace
        close_websocket
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
      ws.log(err)
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
          begin
            ws.email_senders_for_date(date_to_check)
          rescue NoMethodError => err
            ws.log(err)
          end
        end.resume
      end
    end
  end
end