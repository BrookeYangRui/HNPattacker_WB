// Java Struts2 Framework HNP example
// SOURCE: request.getHeader("Host"), request.getHeader("X-Forwarded-Host")
// ADDITION: Struts2 framework, interceptors, value stack pollution
// SINK: send email with polluted reset link

import com.opensymphony.xwork2.ActionSupport;
import com.opensymphony.xwork2.ActionContext;
import com.opensymphony.xwork2.util.ValueStack;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpSession;
import java.util.Properties;
import javax.mail.*;
import javax.mail.internet.*;

public class Struts2HnpAction extends ActionSupport {
    
    private String email;
    private String token;
    private String pollutedHost;
    private String userAgent;
    private Long requestTime;
    
    // Struts2 interceptor for HNP
    public static class HnpInterceptor implements com.opensymphony.xwork2.interceptor.Interceptor {
        
        @Override
        public void init() {}
        
        @Override
        public void destroy() {}
        
        @Override
        public String intercept(com.opensymphony.xwork2.ActionInvocation invocation) throws Exception {
            // Get HTTP request
            HttpServletRequest request = (HttpServletRequest) ActionContext.getContext()
                .get(com.opensymphony.struts2.StrutsStatics.HTTP_REQUEST);
            
            // SOURCE: extract host from request headers
            String host = request.getHeader("Host");
            if (request.getHeader("X-Forwarded-Host") != null) {
                host = request.getHeader("X-Forwarded-Host");
            }
            
            // Get Struts2 context
            ActionContext context = invocation.getInvocationContext();
            ValueStack stack = context.getValueStack();
            HttpSession session = request.getSession();
            
            // Store polluted host in Struts2 value stack
            stack.set("polluted_host", host);
            stack.set("user_agent", request.getHeader("User-Agent"));
            stack.set("request_time", System.currentTimeMillis());
            stack.set("struts2_framework", true);
            
            // Also store in session
            session.setAttribute("polluted_host", host);
            session.setAttribute("user_agent", request.getHeader("User-Agent"));
            session.setAttribute("request_time", System.currentTimeMillis());
            session.setAttribute("struts2_framework", true);
            
            return invocation.invoke();
        }
    }
    
    // Forgot password form
    public String forgotForm() {
        return SUCCESS;
    }
    
    // Forgot password submission
    public String forgotSubmit() throws Exception {
        if (email == null || email.isEmpty()) {
            email = "user@example.com";
        }
        token = "struts2-token-123";
        
        // Get polluted host from Struts2 context
        ActionContext context = ActionContext.getContext();
        ValueStack stack = context.getValueStack();
        HttpSession session = (HttpSession) context.get(com.opensymphony.struts2.StrutsStatics.SESSION);
        
        pollutedHost = (String) stack.findValue("polluted_host");
        userAgent = (String) stack.findValue("user_agent");
        requestTime = (Long) stack.findValue("request_time");
        
        // ADDITION: build reset URL with Struts2 framework context
        StringBuilder resetURL = new StringBuilder();
        resetURL.append("http://").append(pollutedHost).append("/reset/").append(token);
        resetURL.append("?from=struts2_framework&t=").append(token);
        resetURL.append("&framework=struts2&polluted_host=").append(pollutedHost);
        resetURL.append("&user_agent=").append(userAgent);
        resetURL.append("&request_time=").append(requestTime);
        
        String html = String.format(
            "<p>Reset your password: <a href='%s'>%s</a></p>",
            resetURL.toString(), resetURL.toString()
        );
        
        try {
            sendResetEmail(email, html);
            addActionMessage("Reset email sent via Struts2 framework");
        } catch (Exception e) {
            addActionError("Error: " + e.getMessage());
        }
        
        return SUCCESS;
    }
    
    // Password reset
    public String reset() {
        // Get polluted host from Struts2 context
        ActionContext context = ActionContext.getContext();
        ValueStack stack = context.getValueStack();
        
        pollutedHost = (String) stack.findValue("polluted_host");
        userAgent = (String) stack.findValue("user_agent");
        requestTime = (Long) stack.findValue("request_time");
        
        return SUCCESS;
    }
    
    // Context information
    public String context() {
        // Get polluted host from Struts2 context
        ActionContext context = ActionContext.getContext();
        ValueStack stack = context.getValueStack();
        
        pollutedHost = (String) stack.findValue("polluted_host");
        userAgent = (String) stack.findValue("user_agent");
        requestTime = (Long) stack.findValue("request_time");
        
        return SUCCESS;
    }
    
    // Session information
    public String session() {
        // Get polluted host from session
        ActionContext context = ActionContext.getContext();
        HttpSession session = (HttpSession) context.get(com.opensymphony.struts2.StrutsStatics.SESSION);
        
        pollutedHost = (String) session.getAttribute("polluted_host");
        userAgent = (String) session.getAttribute("user_agent");
        requestTime = (Long) session.getAttribute("request_time");
        
        return SUCCESS;
    }
    
    // Struts2 app info
    public String info() {
        return SUCCESS;
    }
    
    // Struts2 app status
    public String status() {
        return SUCCESS;
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
        message.setSubject("Reset your password - Struts2 Framework");
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
