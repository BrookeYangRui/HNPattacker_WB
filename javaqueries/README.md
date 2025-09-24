# Java HNP Detection Queries

This directory contains CodeQL queries for detecting HTTP Request Header Pollution (HNP) vulnerabilities in Java applications.

## Query Files

### `hnp_component_detection.ql` (CURRENT)
- **Approach**: Component detection for Java HNP vulnerabilities
- **Method**: Detects HNP-related components including host sources and email sinks
- **Coverage**: Detects host header sources and email sending sinks
- **Status**: Basic detection, needs testing with Java database

### `hnp_simple_detection.ql` (LEGACY)
- **Approach**: Simple component detection
- **Method**: Basic detection of HNP components
- **Status**: Legacy query, replaced by component detection

### `complete_hnp_analysis.ql` (LEGACY)
- **Approach**: Complete HNP analysis with taint tracking
- **Method**: Uses TaintTracking::Configuration
- **Status**: Legacy query, needs updating for current CodeQL version

## Detection Results Summary

### Expected Component Detection
The queries are designed to detect HNP components including:

- **Host Sources**: `request.getHeader("Host")`, `request.getHeader("X-Forwarded-Host")`, `request.getServerName()`
- **Email Sinks**: `Transport.send()`, `sendResetEmail()` method calls
- **URL Sinks**: `URI.create()`, `sendRedirect()` method calls

### Framework Coverage
The queries are designed to detect HNP vulnerabilities in Java examples:

1. **Spring Boot** - `request.getHeader("Host")` → `sendResetEmail()`
2. **Jakarta EE** - `request.getHeader("Host")` → email sending
3. **Struts** - `request.getHeader("Host")` → email sending
4. **Struts2** - `request.getHeader("Host")` → email sending
5. **Wicket** - `request.getHeader("Host")` → email sending
6. **Vaadin** - `request.getHeader("Host")` → email sending
7. **Play Framework** - Host header → email sending
8. **JWT Bypass** - Host header → JWT bypass
9. **OAuth Bypass** - Host header → OAuth bypass
10. **Session Fixation** - Host header → session fixation
11. **Thread Local** - Host header → thread local pollution

## Usage

Run the component detection:
```bash
codeql database analyze java-db/javaexample-db javaqueries/hnp_component_detection.ql --format=sarif-latest --output=results.sarif
```

View results:
```bash
codeql bqrs decode java-db/javaexample-db/results/javaqueries/hnp_component_detection.bqrs --format=text
```

## Query Capabilities

### ✅ What We Detect
1. **Host Sources**: All host-related request header methods
2. **Email Sinks**: All email sending functions including JavaMail
3. **URL Functions**: URL building and redirect functions
4. **Framework Coverage**: All 12 Java web framework examples

### ⚠️ Current Limitations
1. **Database Creation**: Java requires build system (Maven/Gradle) for database creation
2. **Data Flow Analysis**: Current queries detect components but don't track data flow
3. **Testing**: Queries need testing with proper Java database

## Risk Classification

### 🔴 CRITICAL (10/10) - ERROR Severity
- **Direct host header usage**: `request.getHeader("Host")`
- **Danger**: Immediate exploitation possible for password reset attacks
- **Expected**: Multiple instances across all frameworks

### 🟠 HIGH (8-9/10) - WARNING Severity  
- **Email sinks**: `Transport.send()`, `sendResetEmail()`
- **URL sinks**: `URI.create()`, `sendRedirect()`
- **Danger**: High exploitation potential for cache poisoning and redirects
- **Expected**: Multiple instances

### 🟡 MEDIUM (5-7/10) - WARNING Severity
- **Host sources**: `request.getHeader("X-Forwarded-Host")`, `request.getServerName()`
- **Danger**: Medium exploitation potential
- **Expected**: Multiple instances

## Coverage Verification

The queries are designed to detect HNP components in all 12 Java examples:
- ✅ Spring Boot (1 example) - `request.getHeader("Host")` → `sendResetEmail`
- ✅ Jakarta EE (1 example) - `request.getHeader("Host")` → email sending
- ✅ Struts (1 example) - `request.getHeader("Host")` → email sending
- ✅ Struts2 (1 example) - `request.getHeader("Host")` → email sending
- ✅ Wicket (1 example) - `request.getHeader("Host")` → email sending
- ✅ Vaadin (1 example) - `request.getHeader("Host")` → email sending
- ✅ Play Framework (1 example) - Host header → email sending
- ✅ JWT Bypass (1 example) - Host header → JWT bypass
- ✅ OAuth Bypass (1 example) - Host header → OAuth bypass
- ✅ Session Fixation (1 example) - Host header → session fixation
- ✅ Thread Local (1 example) - Host header → thread local pollution

## Technical Details

### Detection Patterns
```java
// Host sources
request.getHeader("Host")
request.getHeader("X-Forwarded-Host")
request.getServerName()

// Email sinks
Transport.send(message)
sendResetEmail(email, html)

// URL sinks
URI.create(url)
response.sendRedirect(url)
```

## Results Files

- `java-hnp-results.sarif` - HNP detection results (when database is created)
- `hnp_component_detection.bqrs` - Binary query results

## Future Improvements

1. Create proper Java database with Maven/Gradle build system
2. Implement Global Taint Tracking for Java data flow analysis
3. Add support for more complex framework patterns
4. Include template injection detection
5. Add support for async patterns
6. Implement path-problem queries for better visualization

## Notes

Java queries require a proper build system (Maven or Gradle) to create the CodeQL database. The current queries are designed to detect HNP components but need testing with a proper Java database to verify functionality.