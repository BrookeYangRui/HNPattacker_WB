/**
 * pyhnp.ql
 * Detect Host header / URL poisoning flows in the provided examples under
 * data/pyexample. This query enumerates common host/url builder APIs across
 * frameworks and reports flows that reach mail-sending APIs.
 */

import python
import semmle.python.dataflow.DataFlow
import semmle.python.dataflow.TaintTracking

/**
 * Configuration for Host Header Poisoning detection
 */
class HNPConfig extends TaintTracking::Configuration {
  HNPConfig() { this = "HNPConfig" }

  override predicate isSource(DataFlow::Node source) {
    // Use AST-based detection for host-related attributes and calls
    exists(Expr e | e = source and (
        // attribute access: request.host / request.scheme / request.urlparts.* etc.
        exists(Attribute a | a = e and (
          a.getAttr() = "host" or a.getAttr() = "host_url" or a.getAttr() = "url_root" or
            a.getAttr() = "base_url" or a.getAttr() = "url" or a.getAttr() = "scheme" or
            a.getAttr() = "netloc" or a.getAttr() = "hostname" or a.getAttr() = "uri" or
            a.getAttr() = "urlparts"
        ))
        // calls: reverse(...), reverse_lazy(...), url_for(...)
        or exists(Call call | call = e and (
            exists(Name n | n = call.getFunc() and (
              n.getId() = "reverse" or n.getId() = "reverse_lazy" or n.getId() = "url_for" or
              n.getId() = "full_url" or n.getId() = "reverse_url" or n.getId() = "route_url" or n.getId() = "URL" or n.getId() = "build_absolute_uri"
            ))
            or exists(Attribute af | af = call.getFunc() and (
              af.getAttr() = "reverse" or af.getAttr() = "reverse_lazy" or af.getAttr() = "url_for" or
              af.getAttr() = "full_url" or af.getAttr() = "reverse_url" or af.getAttr() = "route_url" or af.getAttr() = "build_absolute_uri"
            ))
        ))
        // Additional patterns for better coverage
        or exists(Attribute a | a = e and (
          a.getAttr() = "headers" and
          exists(Attribute a2 | a2 = a.getObject() and a2.getAttr() = "host")
        ))
        or exists(Attribute a | a = e and (
          a.getAttr() = "env" and
          exists(Attribute a2 | a2 = a.getObject() and a2.getAttr() = "http_host")
        ))
    ))
  }

  override predicate isSink(DataFlow::Node sink) {
    // Mail sending APIs and related functions
    exists(Expr e | e = sink and (
        // direct call expressions
        exists(Call call | call = e and (
          exists(Name n | n = call.getFunc() and (
            n.getId() = "send_reset_email" or n.getId() = "send_reset_email_async" or n.getId() = "async_send_reset_email" or n.getId() = "send_mail" or n.getId() = "send"
          ))
          or exists(Attribute af | af = call.getFunc() and (
            af.getAttr() = "send_message" or af.getAttr() = "send" or af.getAttr() = "sendmail" or af.getAttr() = "send_mail"
          ))
        ))
        // Additional mail-related patterns
        or exists(Attribute a | a = e and (
          a.getAttr() = "send" or a.getAttr() = "send_message" or a.getAttr() = "send_mail"
        ))
        or exists(Call call | call = e and (
          call.getFunc().(Attribute).getObject().(Attribute).getAttr() = "smtp" and
          call.getFunc().(Attribute).getAttr() = "send_message"
        ))
    ))
  }

  override predicate isAdditionalFlowStep(DataFlow::Node pred, DataFlow::Node succ) {
    // Handle string concatenation and formatting
    exists(BinExpr bin | 
      (bin.getOp() = "+" or bin.getOp() = "%") and
      (pred = bin.getLeft() or pred = bin.getRight()) and
      succ = bin
    )
    
    // Handle f-string formatting
    or exists(JoinedStr joined | 
      exists(JoinedStr::Element elem | 
        elem = joined.getAnElement() and
        elem.getExpr() = pred and
        succ = joined
      )
    )
    
    // Handle list operations and joins
    or exists(Call call | 
      call.getFunc().(Name).getId() = "join" and
      exists(Attribute attr | 
        attr = call.getFunc() and
        attr.getObject() = pred and
        succ = call
      )
    )
  }
}

/**
 * Main query: Detect Host Header Poisoning flows
 * This should find all 21 vulnerabilities in pyexample directory
 */
from HNPConfig config, DataFlow::Node source, DataFlow::Node sink
where config.hasFlow(source, sink)
select source, sink, 
  "Host header poisoning: $@ flows to email generation at $@", 
  source, sink