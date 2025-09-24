/**
 * @name Java HNP Component Detection
 * @description Detect Host Header Pollution components in Java
 * @kind problem
 * @problem.severity warning
 * @id java/hnp-component-detection
 */

import java

from MethodAccess ma
where
  // Host header sources
  (ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getHeader") and
   exists(StringLiteral s | s = ma.getArgument(0) and s.getValue() = "Host"))
  or
  (ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getHeader") and
   exists(StringLiteral s | s = ma.getArgument(0) and s.getValue() = "X-Forwarded-Host"))
  or
  ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getServerName")
  or
  // Email sinks
  ma.getMethod().hasQualifiedName("javax.mail", "Transport", "send")
  or
  ma.getMethod().getName() = "sendResetEmail"
  or
  // URL sinks
  (ma.getMethod().hasQualifiedName("java.net", "URI", "create"))
  or
  ma.getMethod().getName() = "sendRedirect"
select ma, "HNP Component Found: $@", ma, "component"
