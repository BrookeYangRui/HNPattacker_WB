# Ruby Padrino Framework HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Padrino framework, application structure, context pollution
# SINK: send email with polluted reset link

require 'sinatra'
require 'net/smtp'
require 'json'
require 'securerandom'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Padrino-like application structure
class PadrinoApp
  attr_accessor :request, :response, :session, :params, :env
  
  def initialize
    @session = {}
    @params = {}
    @env = {}
  end
  
  # Padrino-like URL helpers
  def default_url_options
    Thread.current[:default_url_options] || { host: (ENV['APP_HOST'] || 'example.com') }
  end
  
  def url_for(path, options = {})
    scheme = ENV['APP_SCHEME'] || 'https'
    host = options[:host] || default_url_options[:host]
    "#{scheme}://#{host}#{path}"
  end
  
  def reset_password_url(token)
    url_for("/reset/#{token}")
  end
  
  # Padrino-like before filter
  def before_filter
    # SOURCE: extract host from request headers
    host = @request.host
    if forwarded_host = @request.env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # Store polluted host in Padrino context
    @env['padrino.polluted_host'] = host
    @env['padrino.user_agent'] = @request.env["HTTP_USER_AGENT"]
    @env['padrino.request_time'] = Time.now.to_i
    @env['padrino.framework'] = 'padrino'
    
    # Also store in session
    @session[:polluted_host] = host
    @session[:user_agent] = @request.env["HTTP_USER_AGENT"]
    @session[:request_time] = Time.now.to_i
    
    # Simulate Padrino's default_url_options being influenced by headers
    Thread.current[:default_url_options] = { host: host }
  end
  
  def forgot_form
    before_filter
    content_type 'text/html'
    <<~HTML
      <form method="post">
        <input name="email" placeholder="Email">
        <button type="submit">Send Reset</button>
      </form>
    HTML
  end
  
  def forgot_submit
    before_filter
    
    email = @params[:email] || 'user@example.com'
    token = 'padrino-token-123'
    
    # Get polluted host from Padrino context
    polluted_host = @env['padrino.polluted_host']
    user_agent = @env['padrino.user_agent']
    request_time = @env['padrino.request_time']
    
    # ADDITION: build reset URL using Padrino helper (realistic pattern)
    reset_url = reset_password_url(token)
    reset_url += "?from=padrino_framework&t=#{token}"
    reset_url += "&framework=padrino&polluted_host=#{polluted_host}"
    reset_url += "&user_agent=#{user_agent}"
    reset_url += "&request_time=#{request_time}"
    
    html = RESET_TEMPLATE % [reset_url, reset_url]
    
    begin
      send_reset_email(email, html)
      "Reset email sent via Padrino framework"
    rescue => e
      "Error: #{e.message}"
    end
  end
  
  def reset
    before_filter
    
    token = @params[:token]
    polluted_host = @env['padrino.polluted_host']
    user_agent = @env['padrino.user_agent']
    request_time = @env['padrino.request_time']
    
    response = {
      ok: true, 
      token: token,
      framework: 'padrino',
      polluted_host: polluted_host,
      user_agent: user_agent,
      request_time: request_time,
      padrino_framework: true
    }
    
    content_type 'application/json'
    response.to_json
  end
  
  # Padrino context endpoint
  def context
    before_filter
    
    context_info = {
      padrino_context: {
        polluted_host: @env['padrino.polluted_host'],
        user_agent: @env['padrino.user_agent'],
        request_time: @env['padrino.request_time'],
        framework: @env['padrino.framework']
      },
      padrino_session: @session,
      padrino_framework: true,
      context_exposed: true
    }
    
    content_type 'application/json'
    context_info.to_json
  end
  
  private
  
  def send_reset_email(to_addr, html_body)
    from = "no-reply@example.com"
    password = "password"
    
    msg = <<~MESSAGE
      To: #{to_addr}
      Subject: Reset your password - Padrino Framework
      
      #{html_body}
    MESSAGE
    
    smtp = Net::SMTP.new('smtp.gmail.com', 587)
    smtp.enable_starttls
    smtp.start('localhost', from, password, :login) do |smtp|
      smtp.send_message(msg, from, to_addr)
    end
  end
end

# Sinatra app with Padrino-like structure
class PadrinoHnpApp < Sinatra::Base
  set :port, 3000
  
  # Padrino-like URL helpers for Sinatra routes
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
  
  # Padrino-like routing
  get '/forgot' do
    controller = PadrinoApp.new
    controller.request = request
    controller.forgot_form
  end
  
  post '/forgot' do
    controller = PadrinoApp.new
    controller.request = request
    controller.params = params
    controller.forgot_submit
  end
  
  get '/reset/:token' do
    controller = PadrinoApp.new
    controller.request = request
    controller.params = params
    controller.reset
  end
  
  get '/context' do
    controller = PadrinoApp.new
    controller.request = request
    controller.context
  end
  
  # Additional Padrino-like endpoints
  get '/padrino/status' do
    content_type 'application/json'
    {
      framework: 'padrino',
      version: '1.0.0',
      status: 'running',
      padrino_framework: true
    }.to_json
  end
  
  get '/padrino/config' do
    content_type 'application/json'
    {
      framework: 'padrino',
      environment: 'development',
      database: 'sqlite3',
      cache: 'memory',
      padrino_framework: true
    }.to_json
  end
end

PadrinoHnpApp.run!
