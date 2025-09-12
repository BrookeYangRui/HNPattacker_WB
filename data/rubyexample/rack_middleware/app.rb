# Rack Middleware HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Rack middleware chain, context mutation, string concatenation
# SINK: send email with polluted reset link

require 'sinatra'
require 'net/smtp'
require 'json'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Sinatra helpers to simulate Rails-like URL generation
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

# Rack middleware for host extraction
class HostExtractionMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # SOURCE: extract host from request headers
    host = env["HTTP_HOST"]
    if forwarded_host = env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # Store in environment for later use
    env["extracted_host"] = host
    env["rack.session"] ||= {}
    env["rack.session"]["extracted_host"] = host
    # Also pollute thread-local default_url_options to affect helpers
    Thread.current[:default_url_options] = { host: host }
    
    @app.call(env)
  end
end

# Rack middleware for logging
class LoggingMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    puts "[LOG] #{env['REQUEST_METHOD']} #{env['PATH_INFO']}"
    puts "[LOG] Host: #{env['extracted_host']}"
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

# Configure Sinatra with middleware
configure do
  use HostExtractionMiddleware
  use LoggingMiddleware
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
  token = 'rack-token-123'
  
  # Get host from middleware context
  host = request.env["extracted_host"] || request.host
  if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
    host = forwarded_host
  end
  # Ensure helpers read polluted host
  Thread.current[:default_url_options] = { host: host }

  # ADDITION: build reset URL via helper (realistic)
  reset_url = reset_password_url(token)
  reset_url += "?from=rack_middleware&t=#{token}"
  
  # Add session context if available
  if request.env["rack.session"] && request.env["rack.session"]["extracted_host"]
    reset_url += "&session_host=#{request.env["rack.session"]["extracted_host"]}"
  end
  
  html = RESET_TEMPLATE % [reset_url, reset_url]
  
  begin
    send_reset_email(email, html)
    "Reset email sent via Rack middleware"
  rescue => e
    "Error: #{e.message}"
  end
end

get '/reset/:token' do
  content_type 'application/json'
  host = request.env["extracted_host"] || request.host
  {ok: true, token: params[:token], host: host, middleware: true}.to_json
end
