# Ruby Hanami Framework HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Hanami framework, actions, context pollution
# SINK: send email with polluted reset link

require 'hanami/router'
require 'hanami/action'
require 'hanami/controller'
require 'net/smtp'
require 'json'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Hanami-like action for HNP
class HnpAction
  include Hanami::Action
  
  def call(params)
    # SOURCE: extract host from request headers
    host = request.host
    if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # Store polluted host in Hanami context
    @polluted_host = host
    @user_agent = request.env["HTTP_USER_AGENT"]
    @request_time = Time.now.to_i
    @hanami_framework = true
    
    # Also store in session
    session[:polluted_host] = host
    session[:user_agent] = request.env["HTTP_USER_AGENT"]
    session[:request_time] = Time.now.to_i
    session[:hanami_framework] = true
  end
end

# Forgot password form action
class ForgotFormAction < HnpAction
  def call(params)
    super(params)
    
    self.body = <<~HTML
      <form method="post">
        <input name="email" placeholder="Email">
        <button type="submit">Send Reset</button>
      </form>
    HTML
    
    self.headers.merge!('Content-Type' => 'text/html')
  end
end

# Forgot password submission action
class ForgotSubmitAction < HnpAction
  def call(params)
    super(params)
    
    email = params[:email] || 'user@example.com'
    token = 'hanami-token-123'
    
    # ADDITION: build reset URL with Hanami framework context
    reset_url = "http://#{@polluted_host}/reset/#{token}"
    reset_url += "?from=hanami_framework&t=#{token}"
    reset_url += "&framework=hanami&polluted_host=#{@polluted_host}"
    reset_url += "&user_agent=#{@user_agent}"
    reset_url += "&request_time=#{@request_time}"
    
    html = RESET_TEMPLATE % [reset_url, reset_url]
    
    begin
      send_reset_email(email, html)
      self.body = {
        message: 'Reset email sent via Hanami framework',
        hanami_framework: true,
        polluted_host: @polluted_host,
        user_agent: @user_agent,
        request_time: @request_time
      }.to_json
    rescue => e
      self.status = 500
      self.body = { error: e.message }.to_json
    end
    
    self.headers.merge!('Content-Type' => 'application/json')
  end
end

# Password reset action
class ResetAction < HnpAction
  def call(params)
    super(params)
    
    token = params[:token]
    
    self.body = {
      ok: true,
      token: token,
      framework: 'hanami',
      polluted_host: @polluted_host,
      user_agent: @user_agent,
      request_time: @request_time,
      hanami_framework: true
    }.to_json
    
    self.headers.merge!('Content-Type' => 'application/json')
  end
end

# Context information action
class ContextAction < HnpAction
  def call(params)
    super(params)
    
    self.body = {
      hanami_context: {
        polluted_host: @polluted_host,
        user_agent: @user_agent,
        request_time: @request_time,
        framework: 'hanami'
      },
      hanami_framework: true,
      context_exposed: true
    }.to_json
    
    self.headers.merge!('Content-Type' => 'application/json')
  end
end

# Session information action
class SessionAction < HnpAction
  def call(params)
    super(params)
    
    self.body = {
      hanami_session: {
        polluted_host: session[:polluted_host],
        user_agent: session[:user_agent],
        request_time: session[:request_time],
        framework: session[:hanami_framework]
      },
      hanami_framework: true,
      session_exposed: true
    }.to_json
    
    self.headers.merge!('Content-Type' => 'application/json')
  end
end

# Hanami app info action
class InfoAction < HnpAction
  def call(params)
    super(params)
    
    self.body = {
      framework: 'hanami',
      version: '2.0.0',
      status: 'running',
      hanami_framework: true
    }.to_json
    
    self.headers.merge!('Content-Type' => 'application/json')
  end
end

# Hanami app status action
class StatusAction < HnpAction
  def call(params)
    super(params)
    
    self.body = {
      framework: 'hanami',
      actions_count: 6,
      hanami_framework: true
    }.to_json
    
    self.headers.merge!('Content-Type' => 'application/json')
  end
end

# Email sending function
def send_reset_email(to_addr, html_body)
  from = "no-reply@example.com"
  password = "password"
  
  msg = <<~MESSAGE
    To: #{to_addr}
    Subject: Reset your password - Hanami Framework
    
    #{html_body}
  MESSAGE
  
  smtp = Net::SMTP.new('smtp.gmail.com', 587)
  smtp.enable_starttls
  smtp.start('localhost', from, password, :login) do |smtp|
    smtp.send_message(msg, from, to_addr)
  end
end

# Hanami-like application
class HanamiHnpApp
  def initialize
    @router = Hanami::Router.new do
      get '/forgot', to: ForgotFormAction.new
      post '/forgot', to: ForgotSubmitAction.new
      get '/reset/:token', to: ResetAction.new
      get '/context', to: ContextAction.new
      get '/session', to: SessionAction.new
      get '/hanami/info', to: InfoAction.new
      get '/hanami/status', to: StatusAction.new
    end
  end
  
  def call(env)
    @router.call(env)
  end
end

# Start Hanami-like application
app = HanamiHnpApp.new
run app
