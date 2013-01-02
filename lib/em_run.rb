require 'daemons'

Daemons.run_proc("tempo_server", :dir => '/home/ubuntu/.pid/', :backtrace => true) do
  Dir.chdir("/home/ubuntu/deploy/current")
  exec "ruby lib/em.rb"
end