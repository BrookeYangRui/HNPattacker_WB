// Java Jakarta EE Framework HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: Jakarta EE, CDI injection, context pollution
// SINK: send email with polluted reset link

package com.example.hnp.jakarta;

import jakarta.enterprise.context.RequestScoped;
import jakarta.enterprise.context.SessionScoped;
import jakarta.enterprise.inject.Produces;
import jakarta.inject.Inject;
import jakarta.inject.Named;
import jakarta.mail.*;
import jakarta.mail.internet.*;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.Context;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;
import jakarta.ws.rs.core.UriInfo;

import java.io.Serializable;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

@Path("/")
@RequestScoped
public class JakartaEEHnpApplication {

    @Inject
    private HnpContext hnpContext;

    @Context
    private HttpServletRequest request;

    @Context
    private HttpServletResponse response;

    @Context
    private UriInfo uriInfo;

    // Jakarta EE CDI bean for context pollution
    @Named
    @SessionScoped
    public static class HnpContext implements Serializable {
        private static final long serialVersionUID = 1L;
        
        private String pollutedHost;
        private String userAgent;
        private Long requestTime;
        private String sessionId;
        
        public String getPollutedHost() { return pollutedHost; }
        public void setPollutedHost(String pollutedHost) { this.pollutedHost = pollutedHost; }
        
        public String getUserAgent() { return userAgent; }
        public void setUserAgent(String userAgent) { this.userAgent = userAgent; }
        
        public Long getRequestTime() { return requestTime; }
        public void setRequestTime(Long requestTime) { this.requestTime = requestTime; }
        
        public String getSessionId() { return sessionId; }
        public void setSessionId(String sessionId) { this.sessionId = sessionId; }
    }

    // Jakarta EE interceptor for HNP
    @Produces
    @RequestScoped
    public HnpContext produceHnpContext() {
        // SOURCE: extract host from request headers
        String host = request.getHeader("Host");
        String forwardedHost = request.getHeader("X-Forwarded-Host");
        
        if (forwardedHost != null && !forwardedHost.isEmpty()) {
            host = forwardedHost;
        }
        
        // Pollute Jakarta EE context
        hnpContext.setPollutedHost(host);
        hnpContext.setUserAgent(request.getHeader("User-Agent"));
        hnpContext.setRequestTime(System.currentTimeMillis());
        hnpContext.setSessionId(request.getSession().getId());
        
        return hnpContext;
    }

    @GET
    @Path("/forgot")
    @Produces(MediaType.TEXT_HTML)
    public String forgotForm() {
        return """
            <form method="post">
                <input name="email" placeholder="Email">
                <button type="submit">Send Reset</button>
            </form>
            """;
    }

    @POST
    @Path("/forgot")
    @Consumes(MediaType.APPLICATION_FORM_URLENCODED)
    @Produces(MediaType.APPLICATION_JSON)
    public Response forgotSubmit(@FormParam("email") String email) {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }

        String token = "jakarta-token-123";

        // Get polluted host from Jakarta EE context
        String pollutedHost = hnpContext.getPollutedHost();
        String userAgent = hnpContext.getUserAgent();
        Long requestTime = hnpContext.getRequestTime();
        String sessionId = hnpContext.getSessionId();

        // ADDITION: build reset URL with Jakarta EE context
        String resetUrl = "http://" + pollutedHost + "/reset/" + token;
        resetUrl += "?from=jakarta_ee&t=" + token;
        resetUrl += "&framework=jakarta&polluted_host=" + pollutedHost;
        resetUrl += "&user_agent=" + userAgent;
        resetUrl += "&request_time=" + requestTime;
        resetUrl += "&session_id=" + sessionId;

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        try {
            sendResetEmail(email, html);
            
            String response = String.format("""
                {
                    "message": "Reset email sent via Jakarta EE framework",
                    "jakarta_ee": true,
                    "polluted_host": "%s",
                    "user_agent": "%s",
                    "request_time": %d,
                    "session_id": "%s"
                }
                """, pollutedHost, userAgent, requestTime, sessionId);
            
            return Response.ok(response).build();
        } catch (Exception e) {
            String error = String.format("{\"error\": \"%s\"}", e.getMessage());
            return Response.serverError().entity(error).build();
        }
    }

    @GET
    @Path("/reset/{token}")
    @Produces(MediaType.APPLICATION_JSON)
    public Response reset(@PathParam("token") String token) {
        // Get polluted host from Jakarta EE context
        String pollutedHost = hnpContext.getPollutedHost();
        String userAgent = hnpContext.getUserAgent();
        Long requestTime = hnpContext.getRequestTime();
        String sessionId = hnpContext.getSessionId();

        String response = String.format("""
            {
                "ok": true,
                "token": "%s",
                "framework": "jakarta",
                "polluted_host": "%s",
                "user_agent": "%s",
                "request_time": %d,
                "session_id": "%s",
                "jakarta_ee": true
            }
            """, token, pollutedHost, userAgent, requestTime, sessionId);

        return Response.ok(response).build();
    }

    // Jakarta EE context endpoint
    @GET
    @Path("/context")
    @Produces(MediaType.APPLICATION_JSON)
    public Response context() {
        String response = String.format("""
            {
                "jakarta_context": {
                    "polluted_host": "%s",
                    "user_agent": "%s",
                    "request_time": %d,
                    "session_id": "%s"
                },
                "jakarta_ee": true,
                "context_exposed": true
            }
            """, hnpContext.getPollutedHost(), 
                 hnpContext.getUserAgent(), 
                 hnpContext.getRequestTime(), 
                 hnpContext.getSessionId());

        return Response.ok(response).build();
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
        message.setSubject("Reset your password - Jakarta EE");
        message.setContent(htmlBody, "text/html; charset=utf-8");

        Transport.send(message);
    }
}
