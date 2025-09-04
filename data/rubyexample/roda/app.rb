# Ruby Roda Framework HNP example
# SOURCE: request.host, request.env["HTTP_X_FORWARDED_HOST"]
# ADDITION: Roda framework, routing, context pollution
# SINK: send email with polluted reset link

require 'roda'
require 'net/smtp'
require 'json'

RESET_TEMPLATE = "<p>Reset your password: <a href='%s'>%s</a></p>"

# Roda application with HNP
class RodaHnpApp < Roda
  plugin :json
  plugin :json_parser
  
  # Roda middleware for HNP
  plugin :hooks
  
  before do
    # SOURCE: extract host from request headers
    host = request.host
    if forwarded_host = request.env["HTTP_X_FORWARDED_HOST"]
      host = forwarded_host
    end
    
    # Store polluted host in Roda context
    @polluted_host = host
    @user_agent = request.env["HTTP_USER_AGENT"]
    @request_time = Time.now.to_i
    @roda_framework = true
    
    # Also store in session
    session[:polluted_host] = host
    session[:user_agent] = request.env["HTTP_USER_AGENT"]
    session[:request_time] = Time.now.to_i
    session[:roda_framework] = true
  end
  
  # Forgot password form
  route do |r|
    r.on "forgot" do
      r.get do
        <<~HTML
          <form method="post">
            <input name="email" placeholder="Email">
            <button type="submit">Send Reset</button>
          </form>
        HTML
      end
      
      r.post do
        email = r.params["email"] || "user@example.com"
        token = "roda-token-123"
        
        # ADDITION: build reset URL with Roda framework context
        reset_url = "http://#{@polluted_host}/reset/#{token}"
        reset_url += "?from=roda_framework&t=#{token}"
        reset_url += "&framework=roda&polluted_host=#{@polluted_host}"
        reset_url += "&user_agent=#{@user_agent}"
        reset_url += "&request_time=#{@request_time}"
        
        html = RESET_TEMPLATE % [reset_url, reset_url]
        
        begin
          send_reset_email(email, html)
          {
            message: "Reset email sent via Roda framework",
            roda_framework: true,
            polluted_host: @polluted_host,
            user_agent: @user_agent,
            request_time: @request_time
          }
        rescue => e
          response.status = 500
          { error: e.message }
        end
      end
    end
    
    # Password reset
    r.on "reset", String do |token|
      r.get do
        {
          ok: true,
          token: token,
          framework: "roda",
          polluted_host: @polluted_host,
          user_agent: @user_agent,
          request_time: @request_time,
          roda_framework: true
        }
      end
    end
    
    # Context information
    r.get "context" do
      {
        roda_context: {
          polluted_host: @polluted_host,
          user_agent: @user_agent,
          request_time: @request_time,
          framework: "roda"
        },
        roda_framework: true,
        context_exposed: true
      }
    end
    
    # Session information
    r.get "session" do
      {
        roda_session: {
          polluted_host: session[:polluted_host],
          user_agent: session[:user_agent],
          request_time: session[:request_time],
          framework: session[:roda_framework]
        },
        roda_framework: true,
        session_exposed: true
      }
    end
    
    # Roda app info
    r.get "roda", "info" do
      {
        framework: "roda",
        version: "3.0.0",
        status: "running",
        roda_framework: true
      }
    end
    
    # Roda app status
    r.get "roda", "status" do
      {
        framework: "roda",
        routes_count: 6,
        roda_framework: true
      }
    end
    
    # Default route
    r.root do
      "Roda Framework HNP Example"
    end
  end
end

# Email sending function
def send_reset_email(to_addr, html_body)
  from = "no-reply@example.com"
  password = "password"
  
  msg = <<~MESSAGE
    To: #{to_addr}
    Subject: Reset your password - Roda Framework
    
    #{html_body}
  MESSAGE
  
  smtp = Net::SMTP.new('smtp.gmail.com', 587)
  smtp.enable_starttls
  smtp.start('localhost', from, password, :login) do |smtp|
    smtp.send_message(msg, from, to_addr)
  end
end

# Start Roda application
run RodaHnpApp.freeze.app
