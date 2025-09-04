// Java JWT Bypass HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: JWT bypass, token manipulation, authentication bypass
// SINK: send email with polluted reset link

package com.example.hnp.jwtbypass;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.CookieValue;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.util.Properties;
import javax.mail.*;
import javax.mail.internet.*;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.Base64;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

@SpringBootApplication
@Controller
public class JwtBypassHnpApplication {

    // JWT store for demonstration
    private static final ConcurrentHashMap<String, String> jwtStore = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> userJwts = new ConcurrentHashMap<>();
    private static final String JWT_SECRET = "vulnerable-secret-key";

    public static void main(String[] args) {
        SpringApplication.run(JwtBypassHnpApplication.class, args);
    }

    @GetMapping("/forgot")
    public String forgotForm() {
        return "forgot";
    }

    @PostMapping("/forgot")
    @ResponseBody
    public String forgotSubmit(@RequestParam String email, 
                             @CookieValue(value = "jwt_token", required = false) String jwtToken,
                             HttpServletRequest request, 
                             HttpServletResponse response) {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }

        String token = "jwtbypass-token-123";

        // SOURCE: get host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }

        // ADDITION: JWT bypass vulnerability
        if (jwtToken == null || jwtToken.isEmpty()) {
            // Generate new JWT token (vulnerable to bypass)
            jwtToken = generateVulnerableJWT(email, host);
            response.addCookie(new javax.servlet.http.Cookie("jwt_token", jwtToken));
        } else {
            // Validate and potentially bypass JWT
            if (isJwtBypassable(jwtToken)) {
                jwtToken = bypassJWT(jwtToken, host);
            }
        }

        // Store JWT information (vulnerable to manipulation)
        jwtStore.put(jwtToken, host);
        userJwts.put(jwtToken, email);

        // ADDITION: build reset URL with JWT bypass context
        String resetUrl = "http://" + host + "/reset/" + token;
        resetUrl += "?from=jwt_bypass&t=" + token;
        resetUrl += "&jwt_token=" + jwtToken;
        resetUrl += "&polluted_host=" + host;

        // Add JWT bypass indicators
        resetUrl += "&jwt_bypassable=" + isJwtBypassable(jwtToken);
        resetUrl += "&jwt_algorithm=" + getJwtAlgorithm(jwtToken);

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        try {
            sendResetEmail(email, html);
            return "Reset email sent with JWT bypass vulnerability";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    @GetMapping("/reset/{token}")
    @ResponseBody
    public String reset(@PathVariable String token, 
                       @CookieValue(value = "jwt_token", required = false) String jwtToken,
                       HttpServletRequest request) {
        
        // Get JWT information
        String pollutedHost = null;
        String userEmail = null;
        
        if (jwtToken != null) {
            pollutedHost = jwtStore.get(jwtToken);
            userEmail = userJwts.get(jwtToken);
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
               "\", \"jwt_token\": \"" + jwtToken + 
               "\", \"jwt_bypass\": true}";
    }

    @GetMapping("/jwt/{jwtToken}")
    @ResponseBody
    public String getJwtInfo(@PathVariable String jwtToken) {
        // Vulnerable endpoint that exposes JWT information
        String host = jwtStore.get(jwtToken);
        String email = userJwts.get(jwtToken);
        
        Map<String, Object> jwtInfo = new HashMap<>();
        jwtInfo.put("jwt_token", jwtToken);
        jwtInfo.put("polluted_host", host);
        jwtInfo.put("user_email", email);
        jwtInfo.put("jwt_bypassable", isJwtBypassable(jwtToken));
        jwtInfo.put("jwt_algorithm", getJwtAlgorithm(jwtToken));
        jwtInfo.put("jwt_exposed", true);
        
        return jwtInfo.toString();
    }

    @PostMapping("/login")
    @ResponseBody
    public String login(@RequestParam String email, 
                       @RequestParam String password,
                       @CookieValue(value = "jwt_token", required = false) String jwtToken,
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

            // ADDITION: JWT bypass after login
            if (jwtToken == null || jwtToken.isEmpty()) {
                jwtToken = generateVulnerableJWT(email, host);
                response.addCookie(new javax.servlet.http.Cookie("jwt_token", jwtToken));
            }

            // Update JWT with authenticated user info
            jwtStore.put(jwtToken, host);
            userJwts.put(jwtToken, email);

            return "{\"success\": true, \"jwt_token\": \"" + jwtToken + 
                   "\", \"polluted_host\": \"" + host + 
                   "\", \"jwt_bypass\": true}";
        }

        return "{\"success\": false, \"error\": \"Invalid credentials\"}";
    }

    // Vulnerable JWT generation
    private String generateVulnerableJWT(String email, String host) {
        try {
            String header = "{\"alg\":\"HS256\",\"typ\":\"JWT\"}";
            String payload = "{\"email\":\"" + email + "\",\"host\":\"" + host + "\",\"iat\":" + System.currentTimeMillis() / 1000 + "}";
            
            String encodedHeader = Base64.getUrlEncoder().withoutPadding().encodeToString(header.getBytes());
            String encodedPayload = Base64.getUrlEncoder().withoutPadding().encodeToString(payload.getBytes());
            
            // Vulnerable: weak signature
            String signature = generateWeakSignature(encodedHeader + "." + encodedPayload);
            
            return encodedHeader + "." + encodedPayload + "." + signature;
        } catch (Exception e) {
            return "vulnerable.jwt.token." + System.currentTimeMillis();
        }
    }

    // Weak signature generation (vulnerable to bypass)
    private String generateWeakSignature(String data) throws NoSuchAlgorithmException {
        MessageDigest md = MessageDigest.getInstance("MD5"); // Weak algorithm
        byte[] hash = md.digest((data + JWT_SECRET).getBytes());
        return Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
    }

    // Check if JWT is bypassable
    private boolean isJwtBypassable(String jwtToken) {
        if (jwtToken == null || jwtToken.isEmpty()) {
            return false;
        }
        
        String[] parts = jwtToken.split("\\.");
        if (parts.length != 3) {
            return false;
        }
        
        // Check for weak algorithms or missing signature
        try {
            String header = new String(Base64.getUrlDecoder().decode(parts[0]));
            return header.contains("\"alg\":\"none\"") || 
                   header.contains("\"alg\":\"HS256\"") ||
                   parts[2].equals("") ||
                   parts[2].equals("null");
        } catch (Exception e) {
            return true; // Malformed JWT is bypassable
        }
    }

    // Bypass JWT by manipulating the token
    private String bypassJWT(String originalJwt, String newHost) {
        try {
            String[] parts = originalJwt.split("\\.");
            if (parts.length == 3) {
                // Decode payload
                String payload = new String(Base64.getUrlDecoder().decode(parts[1]));
                
                // Replace host in payload
                payload = payload.replaceAll("\"host\":\"[^\"]*\"", "\"host\":\"" + newHost + "\"");
                
                // Re-encode payload
                String newPayload = Base64.getUrlEncoder().withoutPadding().encodeToString(payload.getBytes());
                
                // Create new JWT with manipulated payload
                return parts[0] + "." + newPayload + "." + parts[2];
            }
        } catch (Exception e) {
            // If bypass fails, return original
        }
        return originalJwt;
    }

    // Get JWT algorithm
    private String getJwtAlgorithm(String jwtToken) {
        try {
            String[] parts = jwtToken.split("\\.");
            if (parts.length >= 1) {
                String header = new String(Base64.getUrlDecoder().decode(parts[0]));
                if (header.contains("\"alg\":")) {
                    int start = header.indexOf("\"alg\":\"") + 7;
                    int end = header.indexOf("\"", start);
                    return header.substring(start, end);
                }
            }
        } catch (Exception e) {
            // Return unknown if parsing fails
        }
        return "unknown";
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
        message.setSubject("Reset your password - JWT Bypass");
        message.setContent(htmlBody, "text/html; charset=utf-8");

        Transport.send(message);
    }
}
