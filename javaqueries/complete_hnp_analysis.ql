/**
 * @name Complete Java HNP Analysis
 * @description Detect Host Header Pollution (HNP) style flows in Java web apps: request host/header sources to URL/email/template sinks.
 * @kind problem
 * @problem.severity warning
 * @id java/complete-hnp-analysis
 */

import java
import semmle.code.java.dataflow.DataFlow
import semmle.code.java.dataflow.TaintTracking

/** Sources: request host and headers (Servlet API, frameworks). */
class HostSource extends DataFlow::Node {
  HostSource() {
    exists(MethodAccess ma |
      ma = this.asExpr() and
      // HttpServletRequest.getHeader("Host") / getHeaders / getServerName
      (
        ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getHeader") and
        exists(StringLiteral s | s = ma.getArgument(0) and s.getValue() = "Host")
        or
        ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getHeaders") and
        exists(StringLiteral s2 | s2 = ma.getArgument(0) and s2.getValue() = "X-Forwarded-Host")
        or
        ma.getMethod().hasQualifiedName("javax.servlet.http", "HttpServletRequest", "getServerName")
      )
    )
  }
}

/** Email sinks: JavaMail and helper methods. */
class EmailSink extends DataFlow::Node {
  EmailSink() {
    exists(MethodAccess ma |
      ma = this.asExpr() and
      (
        // Transport.send(Message)
        ma.getMethod().hasQualifiedName("javax.mail", "Transport", "send")
        or
        // JavaMailSender.send(...)
        ma.getMethod().getName() = "send" and
        exists(Type t | t = ma.getQualifier().getType() and t.getErasedType().hasName("JavaMailSender"))
      )
    )
  }
}

/** URL building sinks: new URL(String), URI.create, HttpClient.newHttpRequestBuilder, redirect. */
class URLSink extends DataFlow::Node {
  URLSink() {
    exists(ClassInstanceExpr cie |
      cie = this.asExpr() and cie.getConstructedClass().hasQualifiedName("java.net", "URL")
    )
    or
    exists(MethodAccess ma |
      ma = this.asExpr() and
      (
        ma.getMethod().hasQualifiedName("java.net", "URI", "create") or
        ma.getMethod().getName() = "sendRedirect"
      )
    )
  }
}

/** Template sinks: Spring MVC ModelAndView.setViewName, Thymeleaf/Freemarker renderers (simplified). */
class TemplateSink extends DataFlow::Node {
  TemplateSink() {
    exists(MethodAccess ma |
      ma = this.asExpr() and
      (
        ma.getMethod().hasQualifiedName("org.springframework.web.servlet", "ModelAndView", "setViewName") or
        ma.getMethod().getName() = "process" and ma.getMethod().getDeclaringType().getPackage().getName().matches("org.thymeleaf%")
      )
    )
  }
}

class HNPConfig extends TaintTracking::Configuration {
  HNPConfig() { this = "HNPConfig" }

  override predicate isSource(DataFlow::Node source) { source instanceof HostSource }

  override predicate isSink(DataFlow::Node sink) {
    sink instanceof EmailSink or sink instanceof URLSink or sink instanceof TemplateSink
  }

  override predicate isAdditionalFlowStep(DataFlow::Node pred, DataFlow::Node succ) { false }
}

from HNPConfig cfg, DataFlow::Node src, DataFlow::Node sk
where cfg.hasFlow(src, sk)
select src, sk, "HNP Component Found: request host/header flows to sink $@", sk


