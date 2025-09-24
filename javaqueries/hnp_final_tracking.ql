/**
 * @name Final Java HNP Taint Tracking
 * @description Detect Host Header Pollution using Global Taint Tracking in Java
 * @kind problem
 * @problem.severity warning
 * @id java/hnp-final-tracking
 */

import java
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.dataflow.TaintTracking

module HNPJavaConfiguration implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    // Request header sources
    exists(MethodAccess ma |
      ma = source.asExpr() and
      (
        // HttpServletRequest.getHeader("Host")
        (ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getHeader") and
         exists(StringLiteral s | s = ma.getArgument(0) and s.getValue() = "Host"))
        or
        // HttpServletRequest.getHeader("X-Forwarded-Host")
        (ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getHeader") and
         exists(StringLiteral s | s = ma.getArgument(0) and s.getValue() = "X-Forwarded-Host"))
        or
        // HttpServletRequest.getServerName()
        ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getServerName")
        or
        // VaadinRequest.getHeader("Host")
        (ma.getMethod().getName() = "getHeader" and
         exists(StringLiteral s | s = ma.getArgument(0) and s.getValue() = "Host"))
      )
    )
  }

  predicate isSink(DataFlow::Node sink) {
    // Mail sending sinks
    exists(MethodAccess ma |
      ma = sink.asExpr() and
      (
        // Transport.send(Message)
        ma.getMethod().hasQualifiedName("javax.mail", "Transport", "send")
        or
        // sendResetEmail method calls
        ma.getMethod().getName() = "sendResetEmail"
        or
        // JavaMailSender.send(...)
        (ma.getMethod().getName() = "send" and
         exists(Type t | t = ma.getQualifier().getType() and t.getErasedType().hasName("JavaMailSender")))
      )
    )
    or
    // URL building sinks
    exists(ClassInstanceExpr cie |
      cie = sink.asExpr() and cie.getConstructedClass().hasQualifiedName("java.net", "URL")
    )
    or
    exists(MethodAccess ma |
      ma = sink.asExpr() and
      (
        ma.getMethod().hasQualifiedName("java.net", "URI", "create") or
        ma.getMethod().getName() = "sendRedirect"
      )
    )
  }
}

module HNPJavaFlow = TaintTracking::Global<HNPJavaConfiguration>;

from DataFlow::Node source, DataFlow::Node sink
where HNPJavaFlow::flow(source, sink)
select source, "HNP Vulnerability: Request header flows to sensitive sink", sink, sink.toString()
