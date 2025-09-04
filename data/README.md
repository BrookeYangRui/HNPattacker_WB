# HTTP Request Header Pollution (HNP) Vulnerability Examples

This repository contains comprehensive examples of HTTP Request Header Pollution (HNP) vulnerabilities across multiple programming languages and frameworks. All examples are designed to be detectable by CodeQL analysis and follow the Source-Addition-Sink pattern.

## Overview

HTTP Request Header Pollution (HNP) is a security vulnerability where malicious HTTP headers (particularly `Host` and `X-Forwarded-Host`) are used to manipulate application behavior, potentially leading to phishing attacks, session hijacking, and other security issues.

## Language Coverage

### 1. Python (`pyexample/`) - 21 Vulnerability Types
- **Web Frameworks**: Flask, Django, FastAPI, Tornado, Sanic, Falcon, Bottle, Pyramid, Web2py
- **Template Engines**: Jinja2, Mako
- **Async Patterns**: Starlette, Tornado Async, AIOSMTPLIB
- **Advanced Patterns**: Parameter Pollution, Decorator Chains, Multi-Application, Blueprint Patterns

### 2. Go (`goexample/`) - 15 Vulnerability Types
- **Web Frameworks**: Gin, Echo, Gorilla Mux, Chi Router, Fiber, Iris, Beego
- **Advanced Patterns**: Parameter Pollution, Multi-Application, Context Pollution, Rate Limit Bypass
- **Special Patterns**: WebSocket Hijacking, gRPC Interceptor Pollution, Goroutines

### 3. Java (`javaexample/`) - 15 Vulnerability Types
- **Web Frameworks**: Spring Boot, Jakarta EE, Play Framework, Struts, Struts2, Vaadin, Wicket
- **Advanced Patterns**: Spring Security Bypass, Thread Local, Session Fixation
- **Special Patterns**: JWT Bypass, OAuth Bypass, CompletableFuture

### 4. Ruby (`rubyexample/`) - 15 Vulnerability Types
- **Web Frameworks**: Sinatra, Ruby on Rails, Grape API, Padrino, Hanami, Cuba, Roda
- **Advanced Patterns**: Rack Middleware, Fiber Context, Cache Poisoning
- **Special Patterns**: Redis Injection, Elasticsearch Injection, Thread Local

### 5. JavaScript/Node.js (`jsexample/`) - 15 Vulnerability Types
- **Web Frameworks**: Express.js, Koa.js, Fastify, Hapi, Restify, NestJS, Koa2
- **Advanced Patterns**: Helmet Bypass, Async Context, Proxy Bypass
- **Special Patterns**: MongoDB Injection, GraphQL Injection, Event Loop Pollution

## Total Coverage: 81 Vulnerability Types

This comprehensive collection covers the most common and realistic HNP vulnerability scenarios across all major web development languages and frameworks.

## CodeQL Detection

All examples are designed to be detectable by CodeQL through:

### Data Flow Analysis
- Tracking polluted headers from source to sink
- Framework-specific data flow patterns
- Context pollution detection
- Middleware chain analysis

### Framework-Specific Analysis
- Python: Flask, Django, FastAPI patterns
- Go: Gin, Echo, Gorilla patterns
- Java: Spring, Jakarta, Struts patterns
- Ruby: Sinatra, Rails, Rack patterns
- Node.js: Express, Koa, Fastify patterns

### Advanced Pattern Detection
- Template injection vulnerabilities
- Database injection patterns
- Async context pollution
- Security framework bypass
- Cache poisoning detection

## Common Vulnerability Patterns

### Source (Data Origin)
- `Host` header
- `X-Forwarded-Host` header
- `X-Forwarded-For` header
- `X-Real-IP` header
- Framework-specific host extraction methods

### Addition (Data Processing)
- String concatenation
- Template rendering
- Context storage and manipulation
- Middleware chain execution
- Framework-specific context pollution
- Database query injection

### Sink (Data Usage)
- Email sending functions
- URL generation
- Template rendering
- Response generation
- Database operations
- External API calls

## Real-World Scenarios

These examples cover realistic scenarios including:
- Password reset functionality
- Email sending systems
- API endpoints
- Template rendering
- Database operations
- Session management
- Authentication flows
- Multi-application architectures

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
- Template injection

## Framework-Specific Features

Each language and framework example demonstrates:
- Framework-specific middleware and interceptors
- Context handling mechanisms
- Template engine integration
- Database integration patterns
- Security framework integration
- Custom middleware implementation
- Async programming patterns

## Usage

### For Security Researchers
- Study HNP vulnerability patterns
- Develop detection rules
- Test security tools

### For Developers
- Understand HNP vulnerabilities
- Learn secure coding practices
- Test application security

### For CodeQL Analysis
- All examples are designed for CodeQL detection
- Comprehensive coverage of vulnerability patterns
- Framework-specific analysis support

## Contributing

This repository serves as a comprehensive reference for HNP vulnerabilities. Contributions are welcome to:
- Add new vulnerability patterns
- Improve existing examples
- Add new frameworks or languages
- Enhance CodeQL detection capabilities

## Security Notice

⚠️ **WARNING**: These examples are for educational and research purposes only. Do not use in production environments or against systems you do not own or have explicit permission to test.

## License

This project is provided for educational and research purposes. Please ensure compliance with applicable laws and regulations when using these examples.
