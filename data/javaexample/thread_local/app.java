// Java ThreadLocal HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: ThreadLocal pollution, thread context manipulation, string concatenation
// SINK: send email with polluted reset link

package com.example.hnp.threadlocal;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.*;
import org.springframework.stereotype.Controller;
import javax.servlet.http.HttpServletRequest;
import java.util.Properties;
import javax.mail.*;
import javax.mail.internet.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.CompletableFuture;

@SpringBootApplication
@Controller
public class ThreadLocalHnpApplication {

    // ThreadLocal for storing polluted host information
    private static final ThreadLocal<String> pollutedHostThreadLocal = new ThreadLocal<>();
    private static final ThreadLocal<String> requestTimeThreadLocal = new ThreadLocal<>();
    private static final ThreadLocal<String> userAgentThreadLocal = new ThreadLocal<>();
    
    // Thread pool for background processing
    private static final ExecutorService threadPool = Executors.newFixedThreadPool(5);

    public static void main(String[] args) {
        SpringApplication.run(ThreadLocalHnpApplication.class, args);
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

        String token = "threadlocal-token-123";

        // SOURCE: get host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }

        // ADDITION: pollute ThreadLocal context
        pollutedHostThreadLocal.set(host);
        requestTimeThreadLocal.set(String.valueOf(System.currentTimeMillis()));
        userAgentThreadLocal.set(request.getHeader("User-Agent"));

        // Launch background thread with polluted ThreadLocal
        CompletableFuture.runAsync(() -> {
            processPollutedContext();
        }, threadPool);

        // ADDITION: build reset URL with ThreadLocal pollution
        String resetUrl = "http://" + host + "/reset/" + token;
        resetUrl += "?from=threadlocal&t=" + token;
        resetUrl += "&polluted_host=" + pollutedHostThreadLocal.get();
        resetUrl += "&polluted_time=" + requestTimeThreadLocal.get();

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        try {
            sendResetEmail(email, html);
            
            // Clean up ThreadLocal (but this might not happen in all cases)
            pollutedHostThreadLocal.remove();
            requestTimeThreadLocal.remove();
            userAgentThreadLocal.remove();
            
            return "Reset email sent with ThreadLocal pollution";
        } catch (Exception e) {
            return "Error: " + e.getMessage();
        }
    }

    @GetMapping("/reset/{token}")
    @ResponseBody
    public String reset(@PathVariable String token, HttpServletRequest request) {
        // Get polluted host from ThreadLocal
        String pollutedHost = pollutedHostThreadLocal.get();
        String pollutedTime = requestTimeThreadLocal.get();
        
        return "{\"ok\": true, \"token\": \"" + token + 
               "\", \"polluted_host\": \"" + pollutedHost + 
               "\", \"polluted_time\": \"" + pollutedTime + 
               "\", \"threadlocal_pollution\": true}";
    }

    // Background processing with polluted ThreadLocal
    private void processPollutedContext() {
        try {
            String pollutedHost = pollutedHostThreadLocal.get();
            String pollutedTime = requestTimeThreadLocal.get();
            String pollutedUserAgent = userAgentThreadLocal.get();
            
            System.out.println("[BACKGROUND_THREAD] Processing polluted context:");
            System.out.println("  Host: " + pollutedHost);
            System.out.println("  Time: " + pollutedTime);
            System.out.println("  User-Agent: " + pollutedUserAgent);
            
            // Simulate some processing time
            Thread.sleep(100);
            
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
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
        message.setSubject("Reset your password - ThreadLocal Pollution");
        message.setContent(htmlBody, "text/html; charset=utf-8");

        Transport.send(message);
    }
}
