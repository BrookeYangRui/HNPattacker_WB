// Java Vaadin Framework HNP example
// SOURCE: VaadinRequest.getHeader("Host"), VaadinRequest.getHeader("X-Forwarded-Host")
// ADDITION: Vaadin framework, UI components, session pollution
// SINK: send email with polluted reset link

import com.vaadin.flow.component.UI;
import com.vaadin.flow.component.html.H1;
import com.vaadin.flow.component.html.Form;
import com.vaadin.flow.component.html.Input;
import com.vaadin.flow.component.html.Button;
import com.vaadin.flow.component.html.Div;
import com.vaadin.flow.component.html.Paragraph;
import com.vaadin.flow.router.Route;
import com.vaadin.flow.server.VaadinRequest;
import com.vaadin.flow.server.VaadinSession;
import com.vaadin.flow.component.orderedlayout.VerticalLayout;
import com.vaadin.flow.component.notification.Notification;

import javax.mail.*;
import javax.mail.internet.*;
import java.util.Properties;

@Route("")
public class VaadinHnpApp extends VerticalLayout {
    
    private String pollutedHost;
    private String userAgent;
    private Long requestTime;
    
    public VaadinHnpApp() {
        // Initialize HNP data
        initHnpData();
        
        // Create UI components
        createUI();
    }
    
    // Initialize HNP data from Vaadin context
    private void initHnpData() {
        try {
            // Get Vaadin request and session
            VaadinRequest request = VaadinRequest.getCurrent();
            VaadinSession session = VaadinSession.getCurrent();
            
            if (request != null) {
                // SOURCE: extract host from request headers
                String host = request.getHeader("Host");
                if (request.getHeader("X-Forwarded-Host") != null) {
                    host = request.getHeader("X-Forwarded-Host");
                }
                
                // Store polluted host in Vaadin session
                pollutedHost = host;
                userAgent = request.getHeader("User-Agent");
                requestTime = System.currentTimeMillis();
                
                // Store in Vaadin session
                session.setAttribute("polluted_host", host);
                session.setAttribute("user_agent", userAgent);
                session.setAttribute("request_time", requestTime);
                session.setAttribute("vaadin_framework", true);
            }
        } catch (Exception e) {
            // Fallback values
            pollutedHost = "localhost:8080";
            userAgent = "Unknown";
            requestTime = System.currentTimeMillis();
        }
    }
    
    // Create UI components
    private void createUI() {
        setSizeFull();
        setPadding(true);
        setSpacing(true);
        
        // Title
        add(new H1("Vaadin Framework HNP Example"));
        
        // Forgot password form
        Form forgotForm = new Form();
        forgotForm.setMethod("POST");
        
        Input emailInput = new Input();
        emailInput.setType("email");
        emailInput.setPlaceholder("Email");
        emailInput.setId("email");
        
        Button submitButton = new Button("Send Reset");
        submitButton.addClickListener(e -> handleForgotPassword(emailInput.getValue()));
        
        forgotForm.add(emailInput, submitButton);
        add(forgotForm);
        
        // Status display
        Div statusDiv = new Div();
        statusDiv.setText("Polluted Host: " + pollutedHost);
        add(statusDiv);
        
        // Navigation buttons
        Button contextButton = new Button("Show Context");
        contextButton.addClickListener(e -> showContext());
        
        Button sessionButton = new Button("Show Session");
        sessionButton.addClickListener(e -> showSession());
        
        Button infoButton = new Button("App Info");
        infoButton.addClickListener(e -> showAppInfo());
        
        add(contextButton, sessionButton, infoButton);
    }
    
    // Handle forgot password
    private void handleForgotPassword(String email) {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }
        
        String token = "vaadin-token-123";
        
        // ADDITION: build reset URL with Vaadin framework context
        StringBuilder resetURL = new StringBuilder();
        resetURL.append("http://").append(pollutedHost).append("/reset/").append(token);
        resetURL.append("?from=vaadin_framework&t=").append(token);
        resetURL.append("&framework=vaadin&polluted_host=").append(pollutedHost);
        resetURL.append("&user_agent=").append(userAgent);
        resetURL.append("&request_time=").append(requestTime);
        
        String html = String.format(
            "<p>Reset your password: <a href='%s'>%s</a></p>",
            resetURL.toString(), resetURL.toString()
        );
        
        try {
            sendResetEmail(email, html);
            Notification.show("Reset email sent via Vaadin framework", 3000, Notification.Position.TOP_CENTER);
        } catch (Exception e) {
            Notification.show("Error: " + e.getMessage(), 3000, Notification.Position.TOP_CENTER);
        }
    }
    
    // Show context information
    private void showContext() {
        Div contextDiv = new Div();
        contextDiv.add(new Paragraph("Vaadin Context Information:"));
        contextDiv.add(new Paragraph("Polluted Host: " + pollutedHost));
        contextDiv.add(new Paragraph("User Agent: " + userAgent));
        contextDiv.add(new Paragraph("Request Time: " + requestTime));
        contextDiv.add(new Paragraph("Framework: Vaadin"));
        
        add(contextDiv);
    }
    
    // Show session information
    private void showSession() {
        try {
            VaadinSession session = VaadinSession.getCurrent();
            
            Div sessionDiv = new Div();
            sessionDiv.add(new Paragraph("Vaadin Session Information:"));
            sessionDiv.add(new Paragraph("Polluted Host: " + session.getAttribute("polluted_host")));
            sessionDiv.add(new Paragraph("User Agent: " + session.getAttribute("user_agent")));
            sessionDiv.add(new Paragraph("Request Time: " + session.getAttribute("request_time")));
            sessionDiv.add(new Paragraph("Framework: " + session.getAttribute("vaadin_framework")));
            
            add(sessionDiv);
        } catch (Exception e) {
            Notification.show("Error accessing session: " + e.getMessage(), 3000, Notification.Position.TOP_CENTER);
        }
    }
    
    // Show app information
    private void showAppInfo() {
        Div infoDiv = new Div();
        infoDiv.add(new Paragraph("Vaadin Application Information:"));
        infoDiv.add(new Paragraph("Framework: Vaadin"));
        infoDiv.add(new Paragraph("Version: 14.0.0"));
        infoDiv.add(new Paragraph("Status: Running"));
        infoDiv.add(new Paragraph("HNP Enabled: true"));
        
        add(infoDiv);
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
        message.setSubject("Reset your password - Vaadin Framework");
        message.setContent(htmlBody, "text/html");
        
        Transport.send(message);
    }
}
