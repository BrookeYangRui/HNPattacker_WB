# Ruby Cache Poisoning HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: cache poisoning, cache key manipulation, response caching
# SINK: send email with polluted reset link

require 'sinatra'
require 'net/smtp'
require 'json'
require 'digest'

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

# Simple cache store for demonstration
$cache_store = {}
$cache_keys = {}

# Cache poisoning middleware
class CachePoisoningMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # SOURCE: extract host from request headers
    host = env["HTTP_HOST"]
    if forwarded_host = env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # ADDITION: pollute cache with host information
    cache_key = generate_cache_key(env["PATH_INFO"], host)
    $cache_keys[env["PATH_INFO"]] = cache_key
    
    # Store polluted host in cache
    $cache_store[cache_key] = {
      'polluted_host' => host,
      'request_time' => Time.now.to_i,
      'user_agent' => env["HTTP_USER_AGENT"],
      'path' => env["PATH_INFO"]
    }
    
    # Store in environment for later use
    env["cache_key"] = cache_key
    env["polluted_host"] = host
    env["cache_poisoned"] = true
    # Pollute thread-local default_url_options as seen in frameworks
    Thread.current[:default_url_options] = { host: host }
    
    @app.call(env)
  end
  
  private
  
  def generate_cache_key(path, host)
    # Vulnerable cache key generation
    Digest::MD5.hexdigest("#{path}:#{host}")
  end
end

def send_reset_email(to_addr, html_body)
  from = "no-reply@example.com"
  password = "password"
  
  msg = <<~MESSAGE
    To: #{to_addr}
    Subject: Reset your password
    
    #{html_body}
  MESSAGE
  
  smtp = Net::SMTP.new('smtp.gmail.com', 587)
  smtp.enable_starttls
  smtp.start('localhost', from, password, :login) do |smtp|
    smtp.send_message(msg, from, to_addr)
  end
end

# Cache poisoning helper
def get_cached_response(path, host)
  cache_key = Digest::MD5.hexdigest("#{path}:#{host}")
  $cache_store[cache_key]
end

def poison_cache(path, host, data)
  cache_key = Digest::MD5.hexdigest("#{path}:#{host}")
  $cache_store[cache_key] = data
  cache_key
end

# Configure Sinatra with middleware
configure do
  use CachePoisoningMiddleware
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
  token = 'cache-token-123'
  
  # Get polluted host from cache context
  cache_key = request.env["cache_key"]
  polluted_host = request.env["polluted_host"]
  
  # Get cached data
  cached_data = $cache_store[cache_key]
  
  # Ensure helper reads polluted host
  Thread.current[:default_url_options] = { host: polluted_host }

  # ADDITION: build reset URL via helper (realistic)
  reset_url = reset_password_url(token)
  reset_url += "?from=cache_poisoning&t=#{token}"
  
  # Add cache poisoning indicators
  if cached_data
    reset_url += "&cache_key=#{cache_key}"
    reset_url += "&polluted_host=#{cached_data['polluted_host']}"
    reset_url += "&cache_time=#{cached_data['request_time']}"
  end
  
  # Poison cache with additional data
  additional_cache_data = {
    'email' => email,
    'token' => token,
    'reset_url' => reset_url,
    'poisoned_at' => Time.now.to_i
  }
  
  poison_cache("/forgot", polluted_host, additional_cache_data)
  
  html = RESET_TEMPLATE % [reset_url, reset_url]
  
  begin
    send_reset_email(email, html)
    "Reset email sent via cache poisoning"
  rescue => e
    "Error: #{e.message}"
  end
end

get '/reset/:token' do
  content_type 'application/json'
  token = params[:token]
  
  # Get cache information
  cache_key = request.env["cache_key"]
  polluted_host = request.env["polluted_host"]
  cached_data = $cache_store[cache_key]
  
  response = {
    ok: true, 
    token: token,
    cache_key: cache_key,
    polluted_host: polluted_host,
    cached_data: cached_data,
    cache_poisoning: true
  }
  
  response.to_json
end

# Vulnerable cache endpoint
get '/cache/:path' do
  content_type 'application/json'
  path = "/#{params[:path]}"
  
  # Get all cache entries for this path
  cache_entries = {}
  $cache_keys.each do |cache_path, cache_key|
    if cache_path == path
      cache_entries[cache_key] = $cache_store[cache_key]
    end
  end
  
  {
    path: path,
    cache_entries: cache_entries,
    cache_exposed: true
  }.to_json
end

# Cache manipulation endpoint
post '/cache/poison' do
  content_type 'application/json'
  path = params[:path] || "/"
  host = params[:host] || request.host
  
  # SOURCE: get host from request headers
  if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
    host = forwarded_host
  end
  
  # ADDITION: manually poison cache
  poison_data = {
    'polluted_host' => host,
    'poisoned_at' => Time.now.to_i,
    'poisoned_by' => 'manual',
    'path' => path
  }
  
  cache_key = poison_cache(path, host, poison_data)
  
  {
    success: true,
    cache_key: cache_key,
    path: path,
    host: host,
    cache_poisoned: true
  }.to_json
end

# Cache status endpoint
get '/cache/status' do
  content_type 'application/json'
  {
    total_entries: $cache_store.size,
    cache_keys: $cache_keys,
    cache_store: $cache_store,
    cache_status_exposed: true
  }.to_json
end
