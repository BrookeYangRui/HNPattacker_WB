# Python HNP Vulnerability Examples

This directory contains comprehensive examples of HTTP Request Header Pollution (HNP) vulnerabilities in Python web frameworks and applications. All examples follow the Source-Addition-Sink pattern and are designed to be detectable by CodeQL analysis.

## Vulnerability Coverage

### Web Frameworks (9 types)
1. **Flask** - Basic Flask application with HNP
2. **Django** - Django framework with Class-Based Views
3. **FastAPI** - Modern async web framework
4. **Tornado** - Async web framework
5. **Sanic** - High-performance async framework
6. **Falcon** - Lightweight WSGI framework
7. **Bottle** - Micro web framework
8. **Pyramid** - Full-featured web framework
9. **Web2py** - Full-stack web framework

### Template Engines (2 types)
10. **Jinja2 Template** - Template injection vulnerability
11. **Mako Template** - Template engine injection

### Asynchronous Programming (3 types)
12. **Starlette Async** - Async context pollution
13. **Tornado Async** - Async handler pollution
14. **AIOSMTPLIB Async** - Async email context pollution

### Advanced Patterns (7 types)
15. **Parameter Pollution** - Multiple parameter handling
16. **Decorator Chain** - Function decorator pollution
17. **Multi-Application** - Blueprint and app registration
18. **Flask Blueprint** - Blueprint-specific context
19. **Flask Decorator** - Custom decorator pollution
20. **Flask Multi-App** - Multiple application instances
21. **Django CBV** - Class-Based View pollution

## CodeQL Detection

All examples are designed to be detectable by CodeQL through:

- **Data Flow Analysis**: Tracking polluted headers from source to sink
- **Context Pollution**: Framework-specific context manipulation
- **Template Injection**: Template engine vulnerabilities
- **Async Context**: Asynchronous programming vulnerabilities
- **Framework APIs**: Framework-specific method calls

## Common Vulnerability Patterns

### Source (Data Origin)
- `request.host`
- `request.headers.get('X-Forwarded-Host')`
- `request.headers.get('Host')`
- `url_for()` function calls

### Addition (Data Processing)
- String concatenation
- Template rendering
- Context dictionary manipulation
- Decorator chain execution
- Blueprint registration
- Async context pollution

### Sink (Data Usage)
- `send_mail()` function
- Template rendering
- URL generation
- Email sending
- Response generation

## Real-World Scenarios

These examples cover realistic scenarios including:
- Password reset functionality
- Email sending systems
- Template rendering
- API endpoints
- Multi-application architectures
- Asynchronous operations
- Framework-specific features

## Security Implications

HNP vulnerabilities can lead to:
- Phishing attacks through manipulated URLs
- Session hijacking
- Cross-site scripting (XSS)
- Open redirects
- Information disclosure
- Authentication bypass

## Framework-Specific Features

Each framework example demonstrates:
- Framework-specific middleware
- Context handling mechanisms
- Template engine integration
- Async programming patterns
- Security framework integration
- Custom decorators and filters

## Total Coverage: 21 Vulnerability Types

This comprehensive collection covers the most common and realistic HNP vulnerability scenarios in Python web applications, making it an excellent resource for security research, testing, and CodeQL analysis.
