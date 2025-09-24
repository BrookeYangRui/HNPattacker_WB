// Spring Boot HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: string concatenation, query param addition
// SINK: send email with polluted reset link

package com.example.hnp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import jakarta.servlet.http.HttpServletRequest;
import java.util.Properties;
import jakarta.mail.*;
import jakarta.mail.internet.*;

@SpringBootApplication
@Controller
public class HnpApplication {

    public static void main(String[] args) {
        SpringApplication.run(HnpApplication.class, args);
    }

    @GetMapping("/forgot")
    public String forgotForm() {
        return "forgot";
    }

    @PostMapping("/forgot")
    @ResponseBody
    public String forgotSubmit(@RequestParam String email, HttpServletRequest request) {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }

        String token = "random-token-123";

        // SOURCE: get host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }

        // ADDITION: build reset URL with query params
        String resetUrl = "http://" + host + "/reset/" + token;
        resetUrl += "?from=forgot&t=" + token;

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        try {
            sendResetEmail(email, html);
            return "Reset email sent";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    @GetMapping("/reset/{token}")
    @ResponseBody
    public String reset(@PathVariable String token) {
        return "{\"ok\": true, \"token\": \"" + token + "\"}";
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
        message.setSubject("Reset your password");
        message.setContent(htmlBody, "text/html; charset=utf-8");

        Transport.send(message);
    }
}
