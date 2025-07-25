/**
 * Host Name Pollution (HNP) Detector
 * General-purpose CodeQL query for white-box taint analysis.
 */

import python

// module MyFlow = DataFlow::Global<MyFlowConfiguration>;
//  class HNPTaintConfig extends TaintTracking::Configuration {
//    HNPTaintConfig() { this = "HNPTaintConfig" }
 
//    override predicate isSource(DataFlow::Node source) {
//      exists(Subscript s |
//        s = source.asExpr() and
//        s.getBase().toString().regexpMatch(".*request\\.headers$") and
//        s.getIndex().toString().regexpMatch(".*Host.*")
//      )
//      or
//      exists(Call c |
//        c = source.asExpr() and
//        c.getCallee().toString().regexpMatch(".*get_host$")
//      )
//      or
//      exists(Subscript s |
//        s = source.asExpr() and
//        s.getBase().toString().regexpMatch(".*request\\.META$") and
//        s.getIndex().toString().regexpMatch(".*HTTP_HOST.*")
//      )
//    }
 
//    override predicate isSink(DataFlow::Node sink) {
//      exists(Call c |
//        c.getArgument(0) = sink.asExpr() and
//        (
//          c.getCallee().toString().regexpMatch(".*send_email$") or
//          c.getCallee().toString().regexpMatch(".*send_mail$") or
//          c.getCallee().toString().regexpMatch(".*EmailMessage$") or
//          c.getCallee().toString().regexpMatch(".*mail\\.send$")
//        )
//      )
//    }
 
//    override predicate isSanitizer(DataFlow::Node node) {
//      exists(Call c |
//        c.getArgument(0) = node.asExpr() and
//        (
//          c.getCallee().toString().regexpMatch(".*validate_host.*") or
//          c.getCallee().toString().regexpMatch(".*re\\.match$") or
//          c.getCallee().toString().regexpMatch(".*re\\.search$") or
//          c.getCallee().toString().regexpMatch(".*startswith$")
//        )
//      )
//      or
//      exists(Compare cmp |
//        cmp.getLeft() = node.asExpr() and
//        cmp.getLeft().toString().regexpMatch(".*host$") and
//        cmp.getRight().toString().regexpMatch(".*ALLOWED_HOSTS.*")
//      )
//    }
//  }
 
//  from DataFlow::PathNode source, DataFlow::PathNode sink, HNPTaintConfig cfg
//  where cfg.hasFlowPath(source, sink)
//  let isProtected =
//    exists(DataFlow::PathNode mid |
//      cfg.isSanitizer(mid.getNode()) and
//      mid.getNode().getLocation().getFile() = source.getNode().getLocation().getFile()
//    )
//  select
//    sink.getNode().getLocation().getFile(),
//    sink.getNode().getLocation().getStartLine(),
//    source.getNode().getLocation().getFile(),
//    source.getNode().getLocation().getStartLine(),
//    source.getNode().toString(),
//    sink.getNode().toString(),
//    isProtected ? "Sanitized" : "Not Sanitized"
 