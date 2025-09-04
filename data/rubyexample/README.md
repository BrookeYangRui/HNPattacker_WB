# Ruby HNP Vulnerability Examples

This directory contains comprehensive examples of HTTP Request Header Pollution (HNP) vulnerabilities in Ruby web frameworks and applications. All examples follow the Source-Addition-Sink pattern and are designed to be detectable by CodeQL analysis.

## Vulnerability Coverage

### Web Frameworks (7 types)
1. **Sinatra** - Lightweight web framework
2. **Ruby on Rails** - Full-stack web framework
3. **Grape API** - REST-like API framework
4. **Padrino** - Modular web framework
5. **Hanami** - Modern web framework
6. **Cuba** - Micro web framework
7. **Roda** - Routing tree web framework

### Advanced Patterns (8 types)
8. **Rack Middleware** - Rack middleware chain pollution
9. **Fiber Context** - Fiber and thread-local storage
10. **Cache Poisoning** - Cache manipulation vulnerabilities
11. **Redis Injection** - Redis query injection
12. **Elasticsearch Injection** - Search query injection
13. **Thread Local** - Thread-local storage pollution
14. **Global Context** - Global context store pollution
15. **Session Pollution** - Session attribute manipulation

## CodeQL Detection

All examples are designed to be detectable by CodeQL through:

- **Data Flow Analysis**: Tracking polluted headers from source to sink
- **Context Pollution**: Framework-specific context manipulation
- **Middleware Chains**: Rack middleware execution patterns
- **Framework APIs**: Framework-specific method calls
- **Database Injection**: NoSQL injection vulnerabilities
- **Cache Manipulation**: Cache poisoning patterns

## Common Vulnerability Patterns

### Source (Data Origin)
- `request.host`
- `request.env["HTTP_X_FORWARDED_HOST"]`
- `env["HTTP_HOST"]`
- `env["HTTP_X_FORWARDED_HOST"]`

### Addition (Data Processing)
- String concatenation
- Context storage and manipulation
- Rack middleware chain execution
- Session attribute pollution
- Global context pollution
- Database query injection

### Sink (Data Usage)
- `send_reset_email()` function
- URL generation
- Email sending
- Response generation
- Template rendering

## Real-World Scenarios

These examples cover realistic scenarios including:
- Password reset functionality
- Email sending systems
- API endpoints
- Cache management
- Database operations
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
- Cache poisoning
- Database injection

## Framework-Specific Features

Each framework example demonstrates:
- Framework-specific middleware
- Context handling mechanisms
- Rack middleware integration
- Session handling
- Template engine integration
- Custom middleware implementation

## Ruby-Specific Vulnerabilities

### Rack Patterns
- Rack middleware chain execution
- Environment variable pollution
- Session attribute manipulation
- Global context pollution

### Framework Patterns
- Before filters and hooks
- Context storage and retrieval
- Session management
- Framework-specific APIs

## Total Coverage: 15 Vulnerability Types

This comprehensive collection covers the most common and realistic HNP vulnerability scenarios in Ruby web applications, including advanced patterns like Redis injection, Elasticsearch injection, and cache poisoning. All examples are designed for CodeQL analysis and security research.
