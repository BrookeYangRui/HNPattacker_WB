# Ruby Grape API Framework HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Grape API, middleware chain, context pollution
# SINK: send email with polluted reset link

require 'sinatra'
require 'grape'
require 'net/smtp'
require 'json'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Grape-like API structure
class GrapeAPI < Grape::API
  version 'v1', using: :header, vendor: 'hnp'
  format :json
  
  # Grape-like middleware for HNP
  before do
    # SOURCE: extract host from request headers
    host = request.host
    if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # Store polluted host in Grape context
    env['grape.polluted_host'] = host
    env['grape.user_agent'] = request.env["HTTP_USER_AGENT"]
    env['grape.request_time'] = Time.now.to_i
    env['grape.framework'] = 'grape'
  end
  
  resource :forgot do
    desc "Show forgot password form"
    get do
      content_type 'text/html'
      <<~HTML
        <form method="post">
          <input name="email" placeholder="Email">
          <button type="submit">Send Reset</button>
        </form>
      HTML
    end
    
    desc "Submit forgot password request"
    params do
      requires :email, type: String, desc: "User email"
    end
    post do
      email = params[:email] || 'user@example.com'
      token = 'grape-token-123'
      
      # Get polluted host from Grape context
      polluted_host = env['grape.polluted_host']
      user_agent = env['grape.user_agent']
      request_time = env['grape.request_time']
      
      # ADDITION: build reset URL with Grape API context
      reset_url = "http://#{polluted_host}/reset/#{token}"
      reset_url += "?from=grape_api&t=#{token}"
      reset_url += "&framework=grape&polluted_host=#{polluted_host}"
      reset_url += "&user_agent=#{user_agent}"
      reset_url += "&request_time=#{request_time}"
      
      html = RESET_TEMPLATE % [reset_url, reset_url]
      
      begin
        send_reset_email(email, html)
        {
          message: "Reset email sent via Grape API framework",
          grape_api: true,
          polluted_host: polluted_host,
          user_agent: user_agent,
          request_time: request_time
        }
      rescue => e
        error!({ error: e.message }, 500)
      end
    end
  end
  
  resource :reset do
    desc "Reset password with token"
    params do
      requires :token, type: String, desc: "Reset token"
    end
    get ':token' do
      token = params[:token]
      
      # Get polluted host from Grape context
      polluted_host = env['grape.polluted_host']
      user_agent = env['grape.user_agent']
      request_time = env['grape.request_time']
      
      {
        ok: true,
        token: token,
        framework: 'grape',
        polluted_host: polluted_host,
        user_agent: user_agent,
        request_time: request_time,
        grape_api: true
      }
    end
  end
  
  # Grape context endpoint
  resource :context do
    desc "Get Grape API context information"
    get do
      {
        grape_context: {
          polluted_host: env['grape.polluted_host'],
          user_agent: env['grape.user_agent'],
          request_time: env['grape.request_time'],
          framework: env['grape.framework']
        },
        grape_api: true,
        context_exposed: true
      }
    end
  end
  
  private
  
  def send_reset_email(to_addr, html_body)
    from = "no-reply@example.com"
    password = "password"
    
    msg = <<~MESSAGE
      To: #{to_addr}
      Subject: Reset your password - Grape API
      
      #{html_body}
    MESSAGE
    
    smtp = Net::SMTP.new('smtp.gmail.com', 587)
    smtp.enable_starttls
    smtp.start('localhost', from, password, :login) do |smtp|
      smtp.send_message(msg, from, to_addr)
    end
  end
end

# Sinatra app with Grape-like structure
class GrapeHnpApp < Sinatra::Base
  set :port, 3000
  
  # Mount Grape-like API
  mount GrapeAPI
  
  # Fallback routes
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
    token = 'grape-token-123'
    
    # Get polluted host from request headers
    host = request.host
    if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # Store in environment for Grape-like context
    env['grape.polluted_host'] = host
    env['grape.user_agent'] = request.env["HTTP_USER_AGENT"]
    env['grape.request_time'] = Time.now.to_i
    env['grape.framework'] = 'grape'
    
    # ADDITION: build reset URL with Grape-like context
    reset_url = "http://#{host}/reset/#{token}"
    reset_url += "?from=grape_api&t=#{token}"
    reset_url += "&framework=grape&polluted_host=#{host}"
    reset_url += "&user_agent=#{request.env["HTTP_USER_AGENT"]}"
    reset_url += "&request_time=#{Time.now.to_i}"
    
    html = RESET_TEMPLATE % [reset_url, reset_url]
    
    begin
      send_reset_email(email, html)
      content_type 'application/json'
      {
        message: "Reset email sent via Grape API framework",
        grape_api: true,
        polluted_host: host
      }.to_json
    rescue => e
      status 500
      content_type 'application/json'
      { error: e.message }.to_json
    end
  end
  
  get '/reset/:token' do
    token = params[:token]
    
    # Get polluted host from environment
    polluted_host = env['grape.polluted_host'] || request.host
    user_agent = env['grape.user_agent'] || request.env["HTTP_USER_AGENT"]
    request_time = env['grape.request_time'] || Time.now.to_i
    
    content_type 'application/json'
    {
      ok: true,
      token: token,
      framework: 'grape',
      polluted_host: polluted_host,
      user_agent: user_agent,
      request_time: request_time,
      grape_api: true
    }.to_json
  end
  
  get '/context' do
    content_type 'application/json'
    {
      grape_context: {
        polluted_host: env['grape.polluted_host'],
        user_agent: env['grape.user_agent'],
        request_time: env['grape.request_time'],
        framework: env['grape.framework']
      },
      grape_api: true,
      context_exposed: true
    }.to_json
  end
  
  private
  
  def send_reset_email(to_addr, html_body)
    from = "no-reply@example.com"
    password = "password"
    
    msg = <<~MESSAGE
      To: #{to_addr}
      Subject: Reset your password - Grape API
      
      #{html_body}
    MESSAGE
    
    smtp = Net::SMTP.new('smtp.gmail.com', 587)
    smtp.enable_starttls
    smtp.start('localhost', from, password, :login) do |smtp|
      smtp.send_message(msg, from, to_addr)
    end
  end
end

GrapeHnpApp.run!
