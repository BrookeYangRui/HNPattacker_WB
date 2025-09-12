# Ruby Fiber Context HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Fiber context pollution, thread-local storage, string concatenation
# SINK: send email with polluted reset link

require 'sinatra'
require 'net/smtp'
require 'json'
require 'fiber'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Global context store for pollution
$fiber_context_store = {}
$thread_local_store = {}

# Rails/Devise-like URL options and helpers
helpers do
  def default_url_options
    # Prefer thread-local options (simulating Rails' ActionMailer::Base.default_url_options)
    Thread.current[:default_url_options] || { host: (ENV['APP_HOST'] || 'example.com') }
  end

  def reset_password_url(token)
    host = default_url_options[:host]
    scheme = ENV['APP_SCHEME'] || 'https'
    "#{scheme}://#{host}/reset/#{token}"
  end
end

# Fiber context pollution middleware
class FiberContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # SOURCE: extract host from request headers
    host = env["HTTP_HOST"]
    if forwarded_host = env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # ADDITION: pollute Fiber context
    current_fiber = Fiber.current
    $fiber_context_store[current_fiber] = {
      'polluted_host' => host,
      'request_time' => Time.now.to_i,
      'user_agent' => env["HTTP_USER_AGENT"]
    }
    
    # Pollute thread-local storage
    Thread.current[:polluted_host] = host
    Thread.current[:polluted_time] = Time.now.to_i
    Thread.current[:polluted_user_agent] = env["HTTP_USER_AGENT"]
    # Simulate Rails' default_url_options being polluted by request headers
    Thread.current[:default_url_options] = { host: host }
    
    # Store in environment for later use
    env["fiber_context"] = $fiber_context_store[current_fiber]
    env["thread_local"] = {
      'host' => Thread.current[:polluted_host],
      'time' => Thread.current[:polluted_time],
      'user_agent' => Thread.current[:polluted_user_agent]
    }
    
    @app.call(env)
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

# Background Fiber for processing polluted context
def process_polluted_context_fiber
  Fiber.new do
    current_fiber = Fiber.current
    fiber_context = $fiber_context_store[current_fiber]
    thread_local = {
      'host' => Thread.current[:polluted_host],
      'time' => Thread.current[:polluted_time],
      'user_agent' => Thread.current[:polluted_user_agent]
    }
    
    puts "[FIBER] Processing polluted context:"
    puts "  Fiber Host: #{fiber_context['polluted_host']}"
    puts "  Fiber Time: #{fiber_context['polluted_time']}"
    puts "  Thread Host: #{thread_local['host']}"
    puts "  Thread Time: #{thread_local['time']}"
    
    # Simulate processing time
    sleep(0.1)
  end
end

# Configure Sinatra with middleware
configure do
  use FiberContextMiddleware
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
  token = 'fiber-token-123'
  
  # Get polluted context for demonstration
  current_fiber = Fiber.current
  fiber_context = $fiber_context_store[current_fiber]
  thread_host = Thread.current[:polluted_host]

  # Build URL using realistic helper that reads thread-local default_url_options
  reset_url = reset_password_url(token)
  reset_url += "?from=fiber_context&t=#{token}"
  
  # Add context pollution indicators
  if fiber_context
    reset_url += "&fiber_host=#{fiber_context['polluted_host']}"
    reset_url += "&fiber_time=#{fiber_context['request_time']}"
  end
  
  if thread_host
    reset_url += "&thread_host=#{thread_host}"
    reset_url += "&thread_time=#{Thread.current[:polluted_time]}"
  end
  
  html = RESET_TEMPLATE % [reset_url, reset_url]
  
  # Launch background Fiber with polluted context
  background_fiber = process_polluted_context_fiber
  background_fiber.resume
  
  begin
    send_reset_email(email, html)
    "Reset email sent via Fiber context pollution"
  rescue => e
    "Error: #{e.message}"
  end
end

get '/reset/:token' do
  content_type 'application/json'
  current_fiber = Fiber.current
  fiber_context = $fiber_context_store[current_fiber]
  
  response = {
    ok: true, 
    token: params[:token],
    fiber_context: fiber_context,
    thread_local: {
      host: Thread.current[:polluted_host],
      time: Thread.current[:polluted_time],
      user_agent: Thread.current[:polluted_user_agent]
    },
    fiber_context_pollution: true
  }
  
  response.to_json
end
