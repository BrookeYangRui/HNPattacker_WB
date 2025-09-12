# Ruby on Rails Framework HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Rails framework, controller filters, session pollution
# SINK: send email with polluted reset link

require 'sinatra'
require 'net/smtp'
require 'json'
require 'securerandom'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Rails-like URL helpers available to controller/actions
def default_url_options
  Thread.current[:default_url_options] || { host: (ENV['APP_HOST'] || 'example.com') }
end

def reset_password_url(token)
  scheme = ENV['APP_SCHEME'] || 'https'
  host = default_url_options[:host]
  "#{scheme}://#{host}/reset/#{token}"
end

# Rails-like controller structure
class RailsController
  attr_accessor :request, :response, :session, :params
  
  def initialize
    @session = {}
    @params = {}
  end
  
  # Rails-like before_action filter
  def before_action
    # SOURCE: extract host from request headers
    host = @request.host
    if forwarded_host = @request.env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # Store polluted host in Rails-like session
    @session[:polluted_host] = host
    @session[:user_agent] = @request.env["HTTP_USER_AGENT"]
    @session[:request_time] = Time.now.to_i
    @session[:rails_framework] = true
    # Simulate Rails' default_url_options being influenced by headers
    Thread.current[:default_url_options] = { host: host }
  end
  
  def forgot_form
    before_action
    content_type 'text/html'
    <<~HTML
      <form method="post">
        <input name="email" placeholder="Email">
        <button type="submit">Send Reset</button>
      </form>
    HTML
  end
  
  def forgot_submit
    before_action
    
    email = @params[:email] || 'user@example.com'
    token = 'rails-token-123'
    
    # Get polluted host from Rails-like session
    polluted_host = @session[:polluted_host]
    user_agent = @session[:user_agent]
    request_time = @session[:request_time]
    
    # ADDITION: build reset URL via helper (realistic Rails/Devise pattern)
    reset_url = reset_password_url(token)
    reset_url += "?from=rails_framework&t=#{token}"
    reset_url += "&framework=rails&polluted_host=#{polluted_host}"
    reset_url += "&user_agent=#{user_agent}"
    reset_url += "&request_time=#{request_time}"
    
    html = RESET_TEMPLATE % [reset_url, reset_url]
    
    begin
      send_reset_email(email, html)
      "Reset email sent via Rails framework"
    rescue => e
      "Error: #{e.message}"
    end
  end
  
  def reset
    before_action
    
    token = @params[:token]
    polluted_host = @session[:polluted_host]
    user_agent = @session[:user_agent]
    request_time = @session[:request_time]
    
    response = {
      ok: true, 
      token: token,
      framework: 'rails',
      polluted_host: polluted_host,
      user_agent: user_agent,
      request_time: request_time,
      rails_framework: true
    }
    
    content_type 'application/json'
    response.to_json
  end
  
  # Rails-like session endpoint
  def session_info
    before_action
    
    session_info = {
      rails_session: @session,
      rails_framework: true,
      session_exposed: true
    }
    
    content_type 'application/json'
    session_info.to_json
  end
  
  private
  
  def send_reset_email(to_addr, html_body)
    from = "no-reply@example.com"
    password = "password"
    
    msg = <<~MESSAGE
      To: #{to_addr}
      Subject: Reset your password - Rails Framework
      
      #{html_body}
    MESSAGE
    
    smtp = Net::SMTP.new('smtp.gmail.com', 587)
    smtp.enable_starttls
    smtp.start('localhost', from, password, :login) do |smtp|
      smtp.send_message(msg, from, to_addr)
    end
  end
end

# Sinatra app with Rails-like structure
class RailsHnpApp < Sinatra::Base
  set :port, 3000
  
  # Rails-like routing
  get '/forgot' do
    controller = RailsController.new
    controller.request = request
    controller.forgot_form
  end
  
  post '/forgot' do
    controller = RailsController.new
    controller.request = request
    controller.params = params
    controller.forgot_submit
  end
  
  get '/reset/:token' do
    controller = RailsController.new
    controller.request = request
    controller.params = params
    controller.reset
  end
  
  get '/session' do
    controller = RailsController.new
    controller.request = request
    controller.session_info
  end
end

RailsHnpApp.run!
