// Java Struts Framework HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: Struts framework, action context, interceptor pollution
// SINK: send email with polluted reset link

package com.example.hnp.struts;

import com.opensymphony.xwork2.ActionSupport;
import com.opensymphony.xwork2.ActionContext;
import com.opensymphony.xwork2.interceptor.Interceptor;
import com.opensymphony.xwork2.interceptor.AbstractInterceptor;
import com.opensymphony.xwork2.ActionInvocation;
import com.opensymphony.xwork2.util.ValueStack;
import com.opensymphony.xwork2.util.logging.Logger;
import com.opensymphony.xwork2.util.logging.LoggerFactory;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.util.Map;
import java.util.Properties;
import javax.mail.*;
import javax.mail.internet.*;

public class StrutsFrameworkHnpApplication extends ActionSupport {

    private String email;
    private String token;
    private String pollutedHost;
    private String userAgent;
    private Long requestTime;
    private String sessionId;

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
    
    public String getSessionId() { return sessionId; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }

    // Struts interceptor for HNP
    public static class HnpInterceptor extends AbstractInterceptor {
        private static final Logger LOG = LoggerFactory.getLogger(HnpInterceptor.class);

        @Override
        public String intercept(ActionInvocation invocation) throws Exception {
            ActionContext context = invocation.getInvocationContext();
            HttpServletRequest request = (HttpServletRequest) context.get(HTTP_REQUEST);
            HttpServletResponse response = (HttpServletResponse) context.get(HTTP_RESPONSE);
            
            // SOURCE: extract host from request headers
            String host = request.getHeader("Host");
            String forwardedHost = request.getHeader("X-Forwarded-Host");
            
            if (forwardedHost != null && !forwardedHost.isEmpty()) {
                host = forwardedHost;
            }
            
            // Store polluted host in Struts context
            ValueStack stack = context.getValueStack();
            stack.set("polluted_host", host);
            stack.set("user_agent", request.getHeader("User-Agent"));
            stack.set("request_time", System.currentTimeMillis());
            stack.set("session_id", request.getSession().getId());
            
            // Also store in session
            HttpSession session = request.getSession();
            session.setAttribute("polluted_host", host);
            session.setAttribute("user_agent", request.getHeader("User-Agent"));
            session.setAttribute("request_time", System.currentTimeMillis());
            
            LOG.info("HNP Interceptor: Polluted host set to " + host);
            
            return invocation.invoke();
        }
    }

    // Forgot form action
    public String forgotForm() {
        return SUCCESS;
    }

    // Forgot submit action
    public String forgotSubmit() {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }

        token = "struts-token-123";

        // Get polluted host from Struts context
        ActionContext context = ActionContext.getContext();
        ValueStack stack = context.getValueStack();
        
        pollutedHost = (String) stack.findValue("polluted_host");
        userAgent = (String) stack.findValue("user_agent");
        requestTime = (Long) stack.findValue("request_time");
        sessionId = (String) stack.findValue("session_id");

        // ADDITION: build reset URL with Struts context
        String resetUrl = "http://" + pollutedHost + "/reset/" + token;
        resetUrl += "?from=struts_framework&t=" + token;
        resetUrl += "&framework=struts&polluted_host=" + pollutedHost;
        resetUrl += "&user_agent=" + userAgent;
        resetUrl += "&request_time=" + requestTime;
        resetUrl += "&session_id=" + sessionId;

        String html = "<p>Reset your password: <a href='" + resetUrl + "'>" + resetUrl + "</a></p>";

        try {
            sendResetEmail(email, html);
            addActionMessage("Reset email sent via Struts framework");
            return SUCCESS;
        } catch (Exception e) {
            addActionError("Error: " + e.getMessage());
            return ERROR;
        }
    }

    // Reset action
    public String reset() {
        // Get polluted host from Struts context
        ActionContext context = ActionContext.getContext();
        ValueStack stack = context.getValueStack();
        
        pollutedHost = (String) stack.findValue("polluted_host");
        userAgent = (String) stack.findValue("user_agent");
        requestTime = (Long) stack.findValue("request_time");
        sessionId = (String) stack.findValue("session_id");

        return SUCCESS;
    }

    // Struts context endpoint
    public String context() {
        ActionContext context = ActionContext.getContext();
        ValueStack stack = context.getValueStack();
        
        // Expose Struts context information
        pollutedHost = (String) stack.findValue("polluted_host");
        userAgent = (String) stack.findValue("user_agent");
        requestTime = (Long) stack.findValue("request_time");
        sessionId = (String) stack.findValue("session_id");

        return SUCCESS;
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
        message.setSubject("Reset your password - Struts Framework");
        message.setContent(htmlBody, "text/html; charset=utf-8");

        Transport.send(message);
    }
}
