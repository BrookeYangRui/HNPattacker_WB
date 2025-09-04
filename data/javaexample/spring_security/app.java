// Spring Security HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: Spring Security context, authentication chain, string concatenation
// SINK: send email with polluted reset link

package com.example.hnp.security;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.bind.annotation.*;
import org.springframework.stereotype.Controller;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import javax.servlet.http.HttpServletRequest;
import java.util.Properties;
import javax.mail.*;
import javax.mail.internet.*;

@SpringBootApplication
@EnableWebSecurity
@Controller
public class SpringSecurityHnpApplication {

    public static void main(String[] args) {
        SpringApplication.run(SpringSecurityHnpApplication.class, args);
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .authorizeRequests()
                .antMatchers("/forgot", "/reset/**").permitAll()
                .anyRequest().authenticated()
            .and()
            .csrf().disable();
        return http.build();
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

        String token = "secure-token-123";

        // SOURCE: get host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }

        // ADDITION: build reset URL with security context
        String resetUrl = "http://" + host + "/reset/" + token;
        resetUrl += "?from=spring_security&t=" + token;
        
        // Add authentication context to URL
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth != null && auth.isAuthenticated()) {
            resetUrl += "&user=" + auth.getName();
        }

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        try {
            sendResetEmail(email, html);
            return "Reset email sent with security context";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    @GetMapping("/reset/{token}")
    @ResponseBody
    public String reset(@PathVariable String token, HttpServletRequest request) {
        // SOURCE: get host from request headers for logging
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }
        
        return "{\"ok\": true, \"token\": \"" + token + "\", \"host\": \"" + host + "\"}";
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
        message.setSubject("Reset your password - Spring Security");
        message.setContent(htmlBody, "text/html; charset=utf-8");

        Transport.send(message);
    }
}
