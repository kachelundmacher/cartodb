require 'resque'
require 'resque/failure/base'
require 'resque/failure/multiple'
require 'resque/failure/redis'

# Load automatically all resque files from lib/resque
Dir[Rails.root.join("lib/resque/*.rb")].each {|f| require f}

conf = Cartodb.config[:redis].symbolize_keys
redis_conf = conf.select { |k, v| [:host, :port, :timeout, :tcp_keepalive].include?(k) }
if redis_conf[:tcp_keepalive] and redis_conf[:tcp_keepalive].is_a? Hash
  redis_conf[:tcp_keepalive] = redis_conf[:tcp_keepalive].symbolize_keys
end

#https://github.com/resque/resque/issues/447
if Rails.env == "development"
  unless Rails.application.config.cache_classes
    Resque.after_fork do |job|
      ActionDispatch::Reloader.cleanup!
      ActionDispatch::Reloader.prepare!
    end
  end
end

Resque.redis = Redis.new(redis_conf)
