require 'watchcat'

# Create a new cat.
cat = Watchcat.new(:timeout => 5, :signal => 'KILL', :info => 'rubykill!')
loop do
  # Do something that might be slow.
  cat.heartbeat
end
cat.close # clean cat's litter box.

# If you call it with a block, the cat cleans its own litter box.
Watchcat.new do |cat|
  loop do
    # Do something that might be slow.
    cat.heartbeat
  end
end
