# Sinatra HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: string concatenation, query param addition
# SINK: send email with polluted reset link

require 'sinatra'
require 'net/smtp'
require 'json'

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
  token = 'random-token-123'
  
  # SOURCE: get host from request headers
  host = request.host
  if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
    host = forwarded_host
  end
  # Simulate Rails default_url_options pollution for helpers
  Thread.current[:default_url_options] = { host: host }

  # ADDITION: build reset URL via helper (realistic pattern)
  reset_url = reset_password_url(token)
  reset_url += "?from=forgot&t=#{token}"
  
  html = RESET_TEMPLATE % [reset_url, reset_url]
  
  begin
    send_reset_email(email, html)
    "Reset email sent"
  rescue => e
    "Error: #{e.message}"
  end
end

get '/reset/:token' do
  content_type 'application/json'
  {ok: true, token: params[:token]}.to_json
end
