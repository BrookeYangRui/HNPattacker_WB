// Java OAuth Bypass HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: OAuth bypass, authorization code manipulation, redirect URI pollution
// SINK: send email with polluted reset link

package com.example.hnp.oauthbypass;

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
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.UUID;
import java.net.URLEncoder;
import java.net.URLDecoder;

@SpringBootApplication
@Controller
public class OAuthBypassHnpApplication {

    // OAuth store for demonstration
    private static final ConcurrentHashMap<String, String> oauthStore = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> userOAuths = new ConcurrentHashMap<>();
    private static final ConcurrentHashMap<String, String> redirectUris = new ConcurrentHashMap<>();
    private static final String OAUTH_CLIENT_ID = "vulnerable-client-id";
    private static final String OAUTH_CLIENT_SECRET = "vulnerable-client-secret";

    public static void main(String[] args) {
        SpringApplication.run(OAuthBypassHnpApplication.class, args);
    }

    @GetMapping("/forgot")
    public String forgotForm() {
        return "forgot";
    }

    @PostMapping("/forgot")
    @ResponseBody
    public String forgotSubmit(@RequestParam String email, 
                             @CookieValue(value = "oauth_token", required = false) String oauthToken,
                             HttpServletRequest request, 
                             HttpServletResponse response) {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }

        String token = "oauthbypass-token-123";

        // SOURCE: get host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }

        // ADDITION: OAuth bypass vulnerability
        if (oauthToken == null || oauthToken.isEmpty()) {
            // Generate new OAuth token (vulnerable to bypass)
            oauthToken = generateVulnerableOAuthToken(email, host);
            response.addCookie(new javax.servlet.http.Cookie("oauth_token", oauthToken));
        } else {
            // Validate and potentially bypass OAuth
            if (isOAuthBypassable(oauthToken)) {
                oauthToken = bypassOAuth(oauthToken, host);
            }
        }

        // Store OAuth information (vulnerable to manipulation)
        oauthStore.put(oauthToken, host);
        userOAuths.put(oauthToken, email);

        // ADDITION: build reset URL with OAuth bypass context
        String resetUrl = "http://" + host + "/reset/" + token;
        resetUrl += "?from=oauth_bypass&t=" + token;
        resetUrl += "&oauth_token=" + oauthToken;
        resetUrl += "&polluted_host=" + host;

        // Add OAuth bypass indicators
        resetUrl += "&oauth_bypassable=" + isOAuthBypassable(oauthToken);
        resetUrl += "&redirect_uri=" + getRedirectUri(oauthToken);

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        try {
            sendResetEmail(email, html);
            return "Reset email sent with OAuth bypass vulnerability";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    @GetMapping("/reset/{token}")
    @ResponseBody
    public String reset(@PathVariable String token, 
                       @CookieValue(value = "oauth_token", required = false) String oauthToken,
                       HttpServletRequest request) {
        
        // Get OAuth information
        String pollutedHost = null;
        String userEmail = null;
        
        if (oauthToken != null) {
            pollutedHost = oauthStore.get(oauthToken);
            userEmail = userOAuths.get(oauthToken);
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
               "\", \"oauth_token\": \"" + oauthToken + 
               "\", \"oauth_bypass\": true}";
    }

    // OAuth authorization endpoint (vulnerable to redirect URI pollution)
    @GetMapping("/oauth/authorize")
    public String oauthAuthorize(@RequestParam String response_type,
                                @RequestParam String client_id,
                                @RequestParam String redirect_uri,
                                @RequestParam(required = false) String state,
                                HttpServletRequest request) {
        
        // SOURCE: get host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }

        // ADDITION: OAuth redirect URI pollution
        String pollutedRedirectUri = redirect_uri;
        if (redirect_uri.contains("localhost") || redirect_uri.contains("127.0.0.1")) {
            // Vulnerable: allow localhost redirect URIs
            pollutedRedirectUri = redirect_uri.replace("localhost", host);
        }

        // Generate authorization code
        String authCode = UUID.randomUUID().toString();
        redirectUris.put(authCode, pollutedRedirectUri);

        // Store OAuth context
        String oauthToken = UUID.randomUUID().toString();
        oauthStore.put(oauthToken, host);
        userOAuths.put(oauthToken, "user@example.com");

        // Build redirect URL with polluted URI
        String redirectUrl = pollutedRedirectUri + "?code=" + authCode;
        if (state != null) {
            redirectUrl += "&state=" + state;
        }
        redirectUrl += "&polluted_host=" + host;
        redirectUrl += "&oauth_bypass=true";

        return "redirect:" + redirectUrl;
    }

    // OAuth token endpoint (vulnerable to bypass)
    @PostMapping("/oauth/token")
    @ResponseBody
    public String oauthToken(@RequestParam String grant_type,
                            @RequestParam String code,
                            @RequestParam String redirect_uri,
                            @RequestParam String client_id,
                            @RequestParam String client_secret,
                            HttpServletRequest request) {
        
        // SOURCE: get host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }

        // ADDITION: OAuth token bypass
        String storedRedirectUri = redirectUris.get(code);
        if (storedRedirectUri != null && isRedirectUriBypassable(redirect_uri, storedRedirectUri)) {
            // Vulnerable: allow redirect URI bypass
            String accessToken = UUID.randomUUID().toString();
            String refreshToken = UUID.randomUUID().toString();

            // Store OAuth context
            oauthStore.put(accessToken, host);
            userOAuths.put(accessToken, "user@example.com");

            return "{\"access_token\": \"" + accessToken + 
                   "\", \"token_type\": \"Bearer\", " +
                   "\"expires_in\": 3600, " +
                   "\"refresh_token\": \"" + refreshToken + 
                   "\", \"polluted_host\": \"" + host + 
                   "\", \"oauth_bypass\": true}";
        }

        return "{\"error\": \"invalid_grant\"}";
    }

    @GetMapping("/oauth/{oauthToken}")
    @ResponseBody
    public String getOAuthInfo(@PathVariable String oauthToken) {
        // Vulnerable endpoint that exposes OAuth information
        String host = oauthStore.get(oauthToken);
        String email = userOAuths.get(oauthToken);
        
        Map<String, Object> oauthInfo = new HashMap<>();
        oauthInfo.put("oauth_token", oauthToken);
        oauthInfo.put("polluted_host", host);
        oauthInfo.put("user_email", email);
        oauthInfo.put("oauth_bypassable", isOAuthBypassable(oauthToken));
        oauthInfo.put("redirect_uri", getRedirectUri(oauthToken));
        oauthInfo.put("oauth_exposed", true);
        
        return oauthInfo.toString();
    }

    // Vulnerable OAuth token generation
    private String generateVulnerableOAuthToken(String email, String host) {
        return "vulnerable_oauth_token_" + UUID.randomUUID().toString().replace("-", "") + 
               "_" + email.hashCode() + "_" + host.hashCode();
    }

    // Check if OAuth is bypassable
    private boolean isOAuthBypassable(String oauthToken) {
        if (oauthToken == null || oauthToken.isEmpty()) {
            return false;
        }
        
        // Check for weak token patterns
        return oauthToken.startsWith("vulnerable_") ||
               oauthToken.contains("localhost") ||
               oauthToken.contains("127.0.0.1") ||
               oauthToken.length() < 32;
    }

    // Bypass OAuth by manipulating the token
    private String bypassOAuth(String originalToken, String newHost) {
        try {
            // Simple bypass: replace host in token
            if (originalToken.contains("localhost")) {
                return originalToken.replace("localhost", newHost);
            }
            if (originalToken.contains("127.0.0.1")) {
                return originalToken.replace("127.0.0.1", newHost);
            }
        } catch (Exception e) {
            // If bypass fails, return original
        }
        return originalToken;
    }

    // Get redirect URI for OAuth token
    private String getRedirectUri(String oauthToken) {
        // This is a simplified implementation
        return "http://localhost:3000/callback";
    }

    // Check if redirect URI is bypassable
    private boolean isRedirectUriBypassable(String requestedUri, String storedUri) {
        try {
            // Vulnerable: allow any redirect URI that contains the stored URI
            return requestedUri.contains(storedUri) ||
                   storedUri.contains(requestedUri) ||
                   requestedUri.contains("localhost") ||
                   requestedUri.contains("127.0.0.1");
        } catch (Exception e) {
            return false;
        }
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
        message.setSubject("Reset your password - OAuth Bypass");
        message.setContent(htmlBody, "text/html; charset=utf-8");

        Transport.send(message);
    }
}
