# Ruby Redis Injection HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Redis injection, NoSQL injection, cache pollution
# SINK: send email with polluted reset link

require 'sinatra'
require 'net/smtp'
require 'json'
require 'redis'
require 'securerandom'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

helpers do
  def default_url_options
    Thread.current[:default_url_options] || { host: (ENV['APP_HOST'] || 'example.com') }
  end

  def reset_password_url(token)
    scheme = ENV['APP_SCHEME'] || 'https'
    host = default_url_options[:host]
    "#{scheme}://#{host}/reset/#{token}"
  end
end

# Redis store for demonstration
$redis_store = {}
$redis_keys = {}

# Redis injection middleware
class RedisInjectionMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    # SOURCE: extract host from request headers
    host = env["HTTP_HOST"]
    if forwarded_host = env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # ADDITION: pollute Redis with host information
    redis_key = generate_redis_key(env["PATH_INFO"], host)
    $redis_keys[env["PATH_INFO"]] = redis_key
    
    # Store polluted host in Redis-like store
    $redis_store[redis_key] = {
      'polluted_host' => host,
      'request_time' => Time.now.to_i,
      'user_agent' => env["HTTP_USER_AGENT"],
      'path' => env["PATH_INFO"],
      'redis_injection' => true
    }
    
    # Store in environment for later use
    env["redis_key"] = redis_key
    env["polluted_host"] = host
    env["redis_injection"] = true
    # Pollute thread-local default_url_options for helpers
    Thread.current[:default_url_options] = { host: host }
    
    @app.call(env)
  end
  
  private
  
  def generate_redis_key(path, host)
    # Vulnerable Redis key generation
    "hnp:#{path}:#{host.gsub(/[^a-zA-Z0-9]/, '')}"
  end
end

def send_reset_email(to_addr, html_body)
  from = "no-reply@example.com"
  password = "password"
  
  msg = <<~MESSAGE
    To: #{to_addr}
    Subject: Reset your password - Redis Injection
    
    #{html_body}
  MESSAGE
  
  smtp = Net::SMTP.new('smtp.gmail.com', 587)
  smtp.enable_starttls
  smtp.start('localhost', from, password, :login) do |smtp|
    smtp.send_message(msg, from, to_addr)
  end
end

# Redis injection helper functions
def get_redis_value(key)
  $redis_store[key]
end

def set_redis_value(key, value)
  $redis_store[key] = value
  key
end

def redis_injection_query(query)
  # Vulnerable: direct Redis query injection
  if query.include?("'") || query.include?('"') || query.include?(';')
    # Simulate Redis injection vulnerability
    return $redis_store.values.select { |v| v['polluted_host'].include?(query.gsub(/['";]/, '')) }
  end
  
  # Normal query
  $redis_store.values
end

# Configure Sinatra with middleware
configure do
  use RedisInjectionMiddleware
end

get '/forgot' do
  content_type 'text/html'
  <<~HTML
    <form method="post">
      <input name="email" placeholder="Email">
      <button type="submit">Send Reset</button>
    </form>
  HTML
end

post '/forgot' do
  email = params[:email] || 'user@example.com'
  token = 'redis-token-123'
  
  # Get polluted host from Redis context
  redis_key = request.env["redis_key"]
  polluted_host = request.env["polluted_host"]
  
  # Get cached data
  cached_data = $redis_store[redis_key]
  
  # Ensure helper reads polluted host
  Thread.current[:default_url_options] = { host: polluted_host }

  # ADDITION: build reset URL via helper (realistic)
  reset_url = reset_password_url(token)
  reset_url += "?from=redis_injection&t=#{token}"
  
  # Add Redis injection indicators
  if cached_data
    reset_url += "&redis_key=#{redis_key}"
    reset_url += "&polluted_host=#{cached_data['polluted_host']}"
    reset_url += "&redis_time=#{cached_data['request_time']}"
  end
  
  # Store additional data in Redis
  additional_data = {
    'email' => email,
    'token' => token,
    'reset_url' => reset_url,
    'injected_at' => Time.now.to_i
  }
  
  set_redis_value(redis_key, additional_data.merge(cached_data || {}))
  
  html = RESET_TEMPLATE % [reset_url, reset_url]
  
  begin
    send_reset_email(email, html)
    "Reset email sent via Redis injection"
  rescue => e
    "Error: #{e.message}"
  end
end

get '/reset/:token' do
  content_type 'application/json'
  token = params[:token]
  
  # Get Redis information
  redis_key = request.env["redis_key"]
  polluted_host = request.env["polluted_host"]
  cached_data = $redis_store[redis_key]
  
  response = {
    ok: true, 
    token: token,
    redis_key: redis_key,
    polluted_host: polluted_host,
    cached_data: cached_data,
    redis_injection: true
  }
  
  response.to_json
end

# Vulnerable Redis endpoint
get '/redis/:path' do
  content_type 'application/json'
  path = "/#{params[:path]}"
  
  # Get all Redis entries for this path
  redis_entries = {}
  $redis_keys.each do |redis_path, redis_key|
    if redis_path == path
      redis_entries[redis_key] = $redis_store[redis_key]
    end
  end
  
  {
    path: path,
    redis_entries: redis_entries,
    redis_exposed: true
  }.to_json
end

# Redis injection test endpoint
post '/redis/inject' do
  content_type 'application/json'
  query = params[:query] || ""
  
  # SOURCE: get host from request headers
  host = request.host
  if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
    host = forwarded_host
  end
  
  # ADDITION: Redis injection vulnerability
  results = redis_injection_query(query)
  
  # Store injection attempt
  injection_key = "injection:#{Time.now.to_i}"
  set_redis_value(injection_key, {
    'query' => query,
    'host' => host,
    'results_count' => results.length,
    'injected_at' => Time.now.to_i
  })
  
  {
    success: true,
    query: query,
    results: results,
    results_count: results.length,
    injection_key: injection_key,
    redis_injection: true
  }.to_json
end

# Redis status endpoint
get '/redis/status' do
  content_type 'application/json'
  {
    total_entries: $redis_store.size,
    redis_keys: $redis_keys,
    redis_store: $redis_store,
    redis_status_exposed: true
  }.to_json
end

# Redis query endpoint (vulnerable to injection)
get '/redis/query' do
  content_type 'application/json'
  query = params[:q] || ""
  
  # Vulnerable: direct query injection
  results = redis_injection_query(query)
  
  {
    query: query,
    results: results,
    results_count: results.length,
    redis_query_injection: true
  }.to_json
end
