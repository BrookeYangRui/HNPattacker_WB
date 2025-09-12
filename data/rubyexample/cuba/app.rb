# Ruby Cuba Framework HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Cuba framework, routing, context pollution
# SINK: send email with polluted reset link

require 'cuba'
require 'cuba/safe'
require 'net/smtp'
require 'json'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Cuba middleware for HNP
class HnpMiddleware
  def initialize(app)
    @app = app
  end
  
  def call(env)
    # SOURCE: extract host from request headers
    host = env["HTTP_HOST"]
    if forwarded_host = env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # Store polluted host in Cuba context
    env["cuba.polluted_host"] = host
    env["cuba.user_agent"] = env["HTTP_USER_AGENT"]
    env["cuba.request_time"] = Time.now.to_i
    env["cuba.framework"] = true
    
    # Simulate Cuba's default_url_options being influenced by headers
    Thread.current[:default_url_options] = { host: host }
    
    @app.call(env)
  end
end

# Cuba-like URL helpers
def default_url_options
  Thread.current[:default_url_options] || { host: (ENV['APP_HOST'] || 'example.com') }
end

def url(path, options = {})
  scheme = ENV['APP_SCHEME'] || 'https'
  host = options[:host] || default_url_options[:host]
  "#{scheme}://#{host}#{path}"
end

def reset_password_url(token)
  url("/reset/#{token}")
end

# Cuba application
Cuba.use HnpMiddleware

Cuba.define do
  # Forgot password form
  on get, "forgot" do
    res.write <<~HTML
      <form method="post">
        <input name="email" placeholder="Email">
        <button type="submit">Send Reset</button>
      </form>
    HTML
    res["Content-Type"] = "text/html"
  end
  
  # Forgot password submission
  on post, "forgot" do
    email = req.params["email"] || "user@example.com"
    token = "cuba-token-123"
    
    # Get polluted host from Cuba context
    polluted_host = req.env["cuba.polluted_host"]
    user_agent = req.env["cuba.user_agent"]
    request_time = req.env["cuba.request_time"]
    
    # ADDITION: build reset URL using Cuba helper (realistic pattern)
    reset_url = reset_password_url(token)
    reset_url += "?from=cuba_framework&t=#{token}"
    reset_url += "&framework=cuba&polluted_host=#{polluted_host}"
    reset_url += "&user_agent=#{user_agent}"
    reset_url += "&request_time=#{request_time}"
    
    html = RESET_TEMPLATE % [reset_url, reset_url]
    
    begin
      send_reset_email(email, html)
      res.write({
        message: "Reset email sent via Cuba framework",
        cuba_framework: true,
        polluted_host: polluted_host,
        user_agent: user_agent,
        request_time: request_time
      }.to_json)
    rescue => e
      res.status = 500
      res.write({ error: e.message }.to_json)
    end
    
    res["Content-Type"] = "application/json"
  end
  
  # Password reset
  on get, "reset", /(\w+)/ do |token|
    # Get polluted host from Cuba context
    polluted_host = req.env["cuba.polluted_host"]
    user_agent = req.env["cuba.user_agent"]
    request_time = req.env["cuba.request_time"]
    
    res.write({
      ok: true,
      token: token,
      framework: "cuba",
      polluted_host: polluted_host,
      user_agent: user_agent,
      request_time: request_time,
      cuba_framework: true
    }.to_json)
    
    res["Content-Type"] = "application/json"
  end
  
  # Context information
  on get, "context" do
    res.write({
      cuba_context: {
        polluted_host: req.env["cuba.polluted_host"],
        user_agent: req.env["cuba.user_agent"],
        request_time: req.env["cuba.request_time"],
        framework: req.env["cuba.framework"]
      },
      cuba_framework: true,
      context_exposed: true
    }.to_json)
    
    res["Content-Type"] = "application/json"
  end
  
  # Cuba app info
  on get, "cuba", "info" do
    res.write({
      framework: "cuba",
      version: "3.9.0",
      status: "running",
      cuba_framework: true
    }.to_json)
    
    res["Content-Type"] = "application/json"
  end
  
  # Cuba app status
  on get, "cuba", "status" do
    res.write({
      framework: "cuba",
      routes_count: 6,
      cuba_framework: true
    }.to_json)
    
    res["Content-Type"] = "application/json"
  end
  
  # Default route
  on root do
    res.write "Cuba Framework HNP Example"
    res["Content-Type"] = "text/plain"
  end
end

# Email sending function
def send_reset_email(to_addr, html_body)
  from = "no-reply@example.com"
  password = "password"
  
  msg = <<~MESSAGE
    To: #{to_addr}
    Subject: Reset your password - Cuba Framework
    
    #{html_body}
  MESSAGE
  
  smtp = Net::SMTP.new('smtp.gmail.com', 587)
  smtp.enable_starttls
  smtp.start('localhost', from, password, :login) do |smtp|
    smtp.send_message(msg, from, to_addr)
  end
end
