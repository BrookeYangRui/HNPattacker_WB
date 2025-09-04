# JavaScript/Node.js HNP Vulnerability Examples

This directory contains comprehensive examples of HTTP Request Header Pollution (HNP) vulnerabilities in JavaScript/Node.js web frameworks and applications. All examples follow the Source-Addition-Sink pattern and are designed to be detectable by CodeQL analysis.

## Vulnerability Coverage

### Web Frameworks (7 types)
1. **Express.js** - Popular Node.js web framework
2. **Koa.js** - Modern Node.js framework
3. **Fastify** - Fast and low overhead web framework
4. **Hapi** - Rich framework for building applications
5. **Restify** - REST API framework
6. **NestJS** - Progressive Node.js framework
7. **Koa2** - Modern async framework

### Advanced Patterns (8 types)
8. **Helmet Bypass** - Security middleware bypass
9. **Async Context** - AsyncLocalStorage pollution
10. **Proxy Bypass** - Proxy header manipulation
11. **MongoDB Injection** - NoSQL injection vulnerabilities
12. **GraphQL Injection** - GraphQL query injection
13. **Event Loop** - Event loop pollution
14. **Promise Chains** - Promise chain pollution
15. **Global Context** - Global context store pollution

## CodeQL Detection

All examples are designed to be detectable by CodeQL through:

- **Data Flow Analysis**: Tracking polluted headers from source to sink
- **Context Pollution**: Framework-specific context manipulation
- **Async Patterns**: AsyncLocalStorage and Promise vulnerabilities
- **Framework APIs**: Framework-specific method calls
- **Database Injection**: NoSQL injection vulnerabilities
- **GraphQL Analysis**: GraphQL-specific vulnerability patterns

## Common Vulnerability Patterns

### Source (Data Origin)
- `req.headers.host`
- `req.headers['x-forwarded-host']`
- `request.info.host`
- `ctx.request.host`
- `request.hostname`

### Addition (Data Processing)
- String concatenation
- Context storage and manipulation
- Middleware chain execution
- Async context pollution
- Global context pollution
- Database query injection

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
- API endpoints
- Database operations
- GraphQL services
- Async operations
- Framework-specific features

## Security Implications

HNP vulnerabilities can lead to:
- Phishing attacks through manipulated URLs
- Session hijacking
- Cross-site scripting (XSS)
- Open redirects
- Information disclosure
- Authentication bypass
- Database injection
- GraphQL manipulation

## Framework-Specific Features

Each framework example demonstrates:
- Framework-specific middleware
- Context handling mechanisms
- Middleware chain execution
- Async programming patterns
- Template engine integration
- Custom middleware implementation

## Node.js-Specific Vulnerabilities

### Async Patterns
- AsyncLocalStorage pollution
- Promise chain pollution
- Event loop pollution
- Async context sharing

### Framework Patterns
- Middleware chain execution
- Context storage and retrieval
- Request/response manipulation
- Framework-specific APIs

## Total Coverage: 15 Vulnerability Types

This comprehensive collection covers the most common and realistic HNP vulnerability scenarios in JavaScript/Node.js web applications, including advanced patterns like MongoDB injection, GraphQL injection, and async context pollution. All examples are designed for CodeQL analysis and security research.
