// Java Wicket Framework HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: Wicket framework, page components, session pollution
// SINK: send email with polluted reset link

import org.apache.wicket.markup.html.WebPage;
import org.apache.wicket.markup.html.form.Form;
import org.apache.wicket.markup.html.form.TextField;
import org.apache.wicket.markup.html.basic.Label;
import org.apache.wicket.markup.html.link.Link;
import org.apache.wicket.markup.html.panel.FeedbackPanel;
import org.apache.wicket.request.mapper.parameter.PageParameters;
import org.apache.wicket.request.cycle.RequestCycle;
import org.apache.wicket.request.http.WebRequest;
import org.apache.wicket.Session;
import org.apache.wicket.model.Model;
import org.apache.wicket.model.PropertyModel;

import javax.mail.*;
import javax.mail.internet.*;
import java.util.Properties;

public class WicketHnpPage extends WebPage {
    
    private String email;
    private String token;
    private String pollutedHost;
    private String userAgent;
    private Long requestTime;
    
    public WicketHnpPage(PageParameters parameters) {
        super(parameters);
        
        // Initialize HNP data
        initHnpData();
        
        // Create page components
        createPageComponents();
    }
    
    // Initialize HNP data from Wicket context
    private void initHnpData() {
        try {
            // Get Wicket request and session
            WebRequest request = (WebRequest) RequestCycle.get().getRequest();
            org.apache.wicket.Session wicketSession = Session.get();
            
            if (request != null) {
                // SOURCE: extract host from request headers
                String host = request.getHeader("Host");
                if (request.getHeader("X-Forwarded-Host") != null) {
                    host = request.getHeader("X-Forwarded-Host");
                }
                
                // Store polluted host in Wicket session
                pollutedHost = host;
                userAgent = request.getHeader("User-Agent");
                requestTime = System.currentTimeMillis();
                
                // Store in Wicket session
                wicketSession.setAttribute("polluted_host", host);
                wicketSession.setAttribute("user_agent", userAgent);
                wicketSession.setAttribute("request_time", requestTime);
                wicketSession.setAttribute("wicket_framework", true);
            }
        } catch (Exception e) {
            // Fallback values
            pollutedHost = "localhost:8080";
            userAgent = "Unknown";
            requestTime = System.currentTimeMillis();
        }
    }
    
    // Create page components
    private void createPageComponents() {
        // Title
        add(new Label("title", "Wicket Framework HNP Example"));
        
        // Feedback panel
        add(new FeedbackPanel("feedback"));
        
        // Forgot password form
        Form<Void> forgotForm = new Form<Void>("forgotForm") {
            @Override
            protected void onSubmit() {
                handleForgotPassword();
            }
        };
        
        TextField<String> emailField = new TextField<>("email", new PropertyModel<>(this, "email"));
        emailField.setRequired(true);
        forgotForm.add(emailField);
        
        add(forgotForm);
        
        // Status display
        add(new Label("status", "Polluted Host: " + pollutedHost));
        
        // Navigation links
        add(new Link<Void>("contextLink") {
            @Override
            public void onClick() {
                showContext();
            }
        });
        
        add(new Link<Void>("sessionLink") {
            @Override
            public void onClick() {
                showSession();
            }
        });
        
        add(new Link<Void>("infoLink") {
            @Override
            public void onClick() {
                showAppInfo();
            }
        });
    }
    
    // Handle forgot password
    private void handleForgotPassword() {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }
        
        token = "wicket-token-123";
        
        // ADDITION: build reset URL with Wicket framework context
        StringBuilder resetURL = new StringBuilder();
        resetURL.append("http://").append(pollutedHost).append("/reset/").append(token);
        resetURL.append("?from=wicket_framework&t=").append(token);
        resetURL.append("&framework=wicket&polluted_host=").append(pollutedHost);
        resetURL.append("&user_agent=").append(userAgent);
        resetURL.append("&request_time=").append(requestTime);
        
        String html = String.format(
            "<p>Reset your password: <a href='%s'>%s</a></p>",
            resetURL.toString(), resetURL.toString()
        );
        
        try {
            sendResetEmail(email, html);
            info("Reset email sent via Wicket framework");
        } catch (Exception e) {
            error("Error: " + e.getMessage());
        }
    }
    
    // Show context information
    private void showContext() {
        info("Wicket Context Information:");
        info("Polluted Host: " + pollutedHost);
        info("User Agent: " + userAgent);
        info("Request Time: " + requestTime);
        info("Framework: Wicket");
    }
    
    // Show session information
    private void showSession() {
        try {
            org.apache.wicket.Session wicketSession = Session.get();
            
            info("Wicket Session Information:");
            info("Polluted Host: " + wicketSession.getAttribute("polluted_host"));
            info("User Agent: " + wicketSession.getAttribute("user_agent"));
            info("Request Time: " + wicketSession.getAttribute("request_time"));
            info("Framework: " + wicketSession.getAttribute("wicket_framework"));
        } catch (Exception e) {
            error("Error accessing session: " + e.getMessage());
        }
    }
    
    // Show app information
    private void showAppInfo() {
        info("Wicket Application Information:");
        info("Framework: Wicket");
        info("Version: 9.0.0");
        info("Status: Running");
        info("HNP Enabled: true");
    }
    
    // Email sending function
    private void sendResetEmail(String to, String htmlBody) throws Exception {
        String from = "no-reply@example.com";
        String password = "password";
        
        Properties props = new Properties();
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.host", "smtp.gmail.com");
        props.put("mail.smtp.port", "587");
        
        Session session = Session.getInstance(props, new Authenticator() {
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(from, password);
            }
        });
        
        Message message = new MimeMessage(session);
        message.setFrom(new InternetAddress(from));
        message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(to));
        message.setSubject("Reset your password - Wicket Framework");
        message.setContent(htmlBody, "text/html");
        
        Transport.send(message);
    }
    
    // Getters and setters
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }
    
    public String getPollutedHost() { return pollutedHost; }
    public void setPollutedHost(String pollutedHost) { this.pollutedHost = pollutedHost; }
    
    public String getUserAgent() { return userAgent; }
    public void setUserAgent(String userAgent) { this.userAgent = userAgent; }
    
    public Long getRequestTime() { return requestTime; }
    public void setRequestTime(Long requestTime) { this.requestTime = requestTime; }
}
