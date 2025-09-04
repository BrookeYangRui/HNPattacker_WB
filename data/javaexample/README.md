# Java HNP Vulnerability Examples

This directory contains comprehensive examples of HTTP Request Header Pollution (HNP) vulnerabilities in Java web frameworks and applications. All examples follow the Source-Addition-Sink pattern and are designed to be detectable by CodeQL analysis.

## Vulnerability Coverage

### Web Frameworks (7 types)
1. **Spring Boot** - Popular Java web framework
2. **Jakarta EE** - Enterprise Java platform
3. **Play Framework** - Reactive web framework
4. **Struts** - MVC framework
5. **Struts2** - Modern MVC framework
6. **Vaadin** - Server-side UI framework
7. **Wicket** - Component-oriented framework

### Advanced Patterns (8 types)
8. **Spring Security** - Security framework bypass
9. **Thread Local** - Thread-local storage pollution
10. **Session Fixation** - Session manipulation
11. **JWT Bypass** - JWT token bypass mechanisms
12. **OAuth Bypass** - OAuth flow bypass
13. **Thread Management** - Thread pool vulnerabilities
14. **Background Threads** - Background processing vulnerabilities
15. **CompletableFuture** - Async programming vulnerabilities

## CodeQL Detection

All examples are designed to be detectable by CodeQL through:

- **Data Flow Analysis**: Tracking polluted headers from source to sink
- **Context Pollution**: Framework-specific context manipulation
- **Thread Safety**: Thread-local and concurrent vulnerabilities
- **Framework APIs**: Framework-specific method calls
- **Security Framework**: Security bypass patterns
- **Async Patterns**: CompletableFuture and async vulnerabilities

## Common Vulnerability Patterns

### Source (Data Origin)
- `request.getHeader("Host")`
- `request.getHeader("X-Forwarded-Host")`
- `ctx.args.get("polluted_host")`
- `stack.findValue("polluted_host")`
- `session.getAttribute("polluted_host")`

### Addition (Data Processing)
- String concatenation
- Context storage and manipulation
- Thread-local storage pollution
- Session attribute manipulation
- Value stack pollution
- Framework context pollution

### Sink (Data Usage)
- `sendResetEmail()` function
- URL generation
- Email sending
- Response generation
- Template rendering

## Real-World Scenarios

These examples cover realistic scenarios including:
- Password reset functionality
- Email sending systems
- OAuth authentication flows
- JWT token handling
- Multi-threaded applications
- Session management
- Framework-specific features

## Security Implications

HNP vulnerabilities can lead to:
- Phishing attacks through manipulated URLs
- Session hijacking
- Cross-site scripting (XSS)
- Open redirects
- Information disclosure
- Authentication bypass
- OAuth flow manipulation
- JWT token manipulation

## Framework-Specific Features

Each framework example demonstrates:
- Framework-specific interceptors
- Context handling mechanisms
- Thread management patterns
- Session handling
- Security framework integration
- Custom interceptor implementation

## Java-Specific Vulnerabilities

### Concurrency Issues
- Thread-local storage pollution
- Thread pool vulnerabilities
- Background thread pollution
- CompletableFuture context pollution

### Framework Patterns
- Interceptor chain execution
- Value stack manipulation
- Session attribute pollution
- Framework-specific APIs
- Security framework bypass

## Total Coverage: 15 Vulnerability Types

This comprehensive collection covers the most common and realistic HNP vulnerability scenarios in Java web applications, including advanced patterns like OAuth bypass, JWT manipulation, and concurrent programming vulnerabilities. All examples are designed for CodeQL analysis and security research.
