// Java Session Fixation HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: session fixation, session hijacking, cookie manipulation
// SINK: send email with polluted reset link

package com.example.hnp.sessionfixation;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.CookieValue;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.util.Properties;
import javax.mail.*;
import javax.mail.internet.*;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@SpringBootApplication
@Controller
public class SessionFixationHnpApplication {

    // Session store for demonstration
    private static final ConcurrentHashMap<String, String> sessionStore = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> userSessions = new ConcurrentHashMap<>();

    public static void main(String[] args) {
        SpringApplication.run(SessionFixationHnpApplication.class, args);
    }

    @GetMapping("/forgot")
    public String forgotForm() {
        return "forgot";
    }

    @PostMapping("/forgot")
    @ResponseBody
    public String forgotSubmit(@RequestParam String email, 
                             @CookieValue(value = "session_id", required = false) String sessionId,
                             HttpServletRequest request, 
                             HttpServletResponse response) {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }

        String token = "sessionfixation-token-123";

        // SOURCE: get host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }

        // ADDITION: session fixation vulnerability
        if (sessionId == null || sessionId.isEmpty()) {
            // Generate new session ID (vulnerable to fixation)
            sessionId = UUID.randomUUID().toString();
            response.addCookie(new javax.servlet.http.Cookie("session_id", sessionId));
        }

        // Store session information (vulnerable to hijacking)
        sessionStore.put(sessionId, host);
        userSessions.put(sessionId, email);

        // Get or create HttpSession
        HttpSession session = request.getSession(true);
        session.setAttribute("polluted_host", host);
        session.setAttribute("user_email", email);
        session.setAttribute("session_id", sessionId);

        // ADDITION: build reset URL with session fixation context
        String resetUrl = "http://" + host + "/reset/" + token;
        resetUrl += "?from=session_fixation&t=" + token;
        resetUrl += "&session_id=" + sessionId;
        resetUrl += "&polluted_host=" + host;

        // Add session fixation indicators
        resetUrl += "&session_created=" + session.getCreationTime();
        resetUrl += "&session_last_access=" + session.getLastAccessedTime();

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        try {
            sendResetEmail(email, html);
            return "Reset email sent with session fixation vulnerability";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    @GetMapping("/reset/{token}")
    @ResponseBody
    public String reset(@PathVariable String token, 
                       @CookieValue(value = "session_id", required = false) String sessionId,
                       HttpServletRequest request) {
        
        // Get session information
        String pollutedHost = null;
        String userEmail = null;
        
        if (sessionId != null) {
            pollutedHost = sessionStore.get(sessionId);
            userEmail = userSessions.get(sessionId);
        }

        // Get from HttpSession if available
        HttpSession session = request.getSession(false);
        if (session != null) {
            if (pollutedHost == null) {
                pollutedHost = (String) session.getAttribute("polluted_host");
            }
            if (userEmail == null) {
                userEmail = (String) session.getAttribute("user_email");
            }
        }

        // Fallback to request headers
        if (pollutedHost == null) {
            pollutedHost = request.getHeader("Host");
            String forwardedHost = request.getHeader("X-Forwarded-Host");
            if (forwardedHost != null && !forwardedHost.isEmpty()) {
                pollutedHost = forwardedHost;
            }
        }

        return "{\"ok\": true, \"token\": \"" + token + 
               "\", \"polluted_host\": \"" + pollutedHost + 
               "\", \"user_email\": \"" + userEmail + 
               "\", \"session_id\": \"" + sessionId + 
               "\", \"session_fixation\": true}";
    }

    @GetMapping("/session/{sessionId}")
    @ResponseBody
    public String getSessionInfo(@PathVariable String sessionId) {
        // Vulnerable endpoint that exposes session information
        String host = sessionStore.get(sessionId);
        String email = userSessions.get(sessionId);
        
        return "{\"session_id\": \"" + sessionId + 
               "\", \"polluted_host\": \"" + host + 
               "\", \"user_email\": \"" + email + 
               "\", \"session_exposed\": true}";
    }

    @PostMapping("/login")
    @ResponseBody
    public String login(@RequestParam String email, 
                       @RequestParam String password,
                       @CookieValue(value = "session_id", required = false) String sessionId,
                       HttpServletRequest request,
                       HttpServletResponse response) {
        
        // Simulate authentication
        if ("user@example.com".equals(email) && "password".equals(password)) {
            
            // SOURCE: get host from request headers
            String host = request.getHeader("Host");
            String forwardedHost = request.getHeader("X-Forwarded-Host");
            if (forwardedHost != null && !forwardedHost.isEmpty()) {
                host = forwardedHost;
            }

            // ADDITION: session fixation after login
            if (sessionId == null || sessionId.isEmpty()) {
                sessionId = UUID.randomUUID().toString();
                response.addCookie(new javax.servlet.http.Cookie("session_id", sessionId));
            }

            // Update session with authenticated user info
            sessionStore.put(sessionId, host);
            userSessions.put(sessionId, email);

            // Create or get HttpSession
            HttpSession session = request.getSession(true);
            session.setAttribute("authenticated", true);
            session.setAttribute("user_email", email);
            session.setAttribute("polluted_host", host);
            session.setAttribute("session_id", sessionId);

            return "{\"success\": true, \"session_id\": \"" + sessionId + 
                   "\", \"polluted_host\": \"" + host + 
                   "\", \"session_fixation\": true}";
        }

        return "{\"success\": false, \"error\": \"Invalid credentials\"}";
    }

    private void sendResetEmail(String to, String htmlBody) throws Exception {
        Properties props = new Properties();
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.host", "smtp.gmail.com");
        props.put("mail.smtp.port", "587");

        Session session = Session.getInstance(props, new Authenticator() {
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication("no-reply@example.com", "password");
            }
        });

        Message message = new MimeMessage(session);
        message.setFrom(new InternetAddress("no-reply@example.com"));
        message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(to));
        message.setSubject("Reset your password - Session Fixation");
        message.setContent(htmlBody, "text/html; charset=utf-8");

        Transport.send(message);
    }
}
