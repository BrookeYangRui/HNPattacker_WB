/**
 * @name Java HNP Detection
 * @description Detects Host Header Pollution vulnerabilities in Java web applications
 * @id java/hnp-detection
 * @kind problem
 * @problem.severity warning
 */

import java
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.dataflow.TaintTracking

module HnpConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    exists(MethodCall call |
      source.asExpr() = call and
      // Servlet: request.getHeader("Host" | X-Forwarded-*)
      call.getMethod().hasName("getHeader") and
      call.getMethod().getDeclaringType().hasQualifiedName("jakarta.servlet.http", "HttpServletRequest") and
      exists(StringLiteral arg |
        call.getArgument(0) = arg and
        arg.getValue().toLowerCase() in ["host", "x-forwarded-host", "x-forwarded-server"]
      )
    )
  }

  predicate isSink(DataFlow::Node sink) {
    exists(MethodCall call |
      sink.asExpr() = call and
      // Email sending methods
      call.getMethod().hasName("send") and
      call.getMethod().getDeclaringType().hasQualifiedName("jakarta.mail", "Transport")
    )
  }
}

module HnpFlow = TaintTracking::Global<HnpConfig>;

from DataFlow::Node source, DataFlow::Node sink
where HnpFlow::flow(source, sink)
select sink, "Host header pollution: user-controlled data from " + 
  source.asExpr().getLocation().getFile().getRelativePath() + 
  ":" + source.asExpr().getLocation().getStartLine() + 
  " flows to " + sink.asExpr().getLocation().getFile().getRelativePath() + 
  ":" + sink.asExpr().getLocation().getStartLine()
