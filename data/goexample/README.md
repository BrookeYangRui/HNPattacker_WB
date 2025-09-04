# Go HNP Vulnerability Examples

This directory contains comprehensive examples of HTTP Request Header Pollution (HNP) vulnerabilities in Go web frameworks and applications. All examples follow the Source-Addition-Sink pattern and are designed to be detectable by CodeQL analysis.

## Vulnerability Coverage

### Web Frameworks (7 types)
1. **Gin** - High-performance HTTP web framework
2. **Echo** - High performance, extensible web framework
3. **Gorilla Mux** - Powerful HTTP router and URL matcher
4. **Chi Router** - Lightweight, expressive HTTP router
5. **Fiber** - Express-inspired web framework
6. **Iris** - Fast, simple yet efficient web framework
7. **Beego** - Full-featured web framework

### Advanced Patterns (8 types)
8. **Parameter Pollution** - Multiple parameter handling
9. **Multi-Application** - Multiple application instances
10. **Context Pollution** - Context manipulation and pollution
11. **Rate Limit Bypass** - Rate limiting bypass mechanisms
12. **WebSocket Hijacking** - WebSocket connection hijacking
13. **gRPC Interceptor** - gRPC metadata pollution
14. **Middleware Chain** - Middleware chain execution
15. **Goroutines** - Concurrent programming vulnerabilities

## CodeQL Detection

All examples are designed to be detectable by CodeQL through:

- **Data Flow Analysis**: Tracking polluted headers from source to sink
- **Context Pollution**: Framework-specific context manipulation
- **Goroutine Context**: Concurrent programming vulnerabilities
- **Framework APIs**: Framework-specific method calls
- **Middleware Chains**: Middleware execution patterns
- **gRPC Analysis**: gRPC-specific vulnerability patterns

## Common Vulnerability Patterns

### Source (Data Origin)
- `c.Request.Host`
- `c.Request.Header.Get("X-Forwarded-Host")`
- `ctx.Host()`
- `ctx.GetHeader("X-Forwarded-Host")`
- `r.Host`
- `r.Header.Get("X-Forwarded-Host")`

### Addition (Data Processing)
- String concatenation
- Context storage (`c.Set()`, `ctx.Values().Set()`)
- Global context pollution
- Middleware chain execution
- Goroutine context sharing
- gRPC metadata manipulation

### Sink (Data Usage)
- `sendResetEmail()` function
- URL generation
- Email sending
- Response generation
- WebSocket broadcasting

## Real-World Scenarios

These examples cover realistic scenarios including:
- Password reset functionality
- Email sending systems
- WebSocket applications
- gRPC services
- Multi-application architectures
- Concurrent operations
- Framework-specific features

## Security Implications

HNP vulnerabilities can lead to:
- Phishing attacks through manipulated URLs
- Session hijacking
- Cross-site scripting (XSS)
- Open redirects
- Information disclosure
- Authentication bypass
- WebSocket hijacking
- gRPC service manipulation

## Framework-Specific Features

Each framework example demonstrates:
- Framework-specific middleware
- Context handling mechanisms
- Middleware chain execution
- Goroutine management
- gRPC interceptor patterns
- WebSocket handling
- Custom middleware implementation

## Go-Specific Vulnerabilities

### Concurrency Issues
- Goroutine context pollution
- Global variable sharing
- Channel communication vulnerabilities
- Context package misuse

### Framework Patterns
- Middleware chain execution
- Context storage and retrieval
- Request/response manipulation
- Framework-specific APIs

## Total Coverage: 15 Vulnerability Types

This comprehensive collection covers the most common and realistic HNP vulnerability scenarios in Go web applications, including advanced patterns like gRPC interception, WebSocket hijacking, and concurrent programming vulnerabilities. All examples are designed for CodeQL analysis and security research.
