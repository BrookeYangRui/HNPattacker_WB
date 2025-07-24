/**
 * Host Name Pollution (HNP) 检测器
 * 标记 Host 头访问为 taint source，跟踪到敏感 sink，检测净化逻辑
 */
import python
import semmle.python.dataflow.new.TaintTracking

class HNPTaintConfig extends TaintTracking::Configuration {
  HNPTaintConfig() { this = "HNPTaintConfig" }

  override predicate isSource(DataFlow::Node source) {
    exists(python.Expr e |
      (
        // request.headers["Host"]
        e instanceof python.Subscript and
        e.getBase().toString().regexpMatch(".*request\\.headers$") and
        e.getIndex().toString().regexpMatch(".*Host.*")
      ) or
      (
        // request.get_host()
        e instanceof python.Call and
        e.getCallee().toString().regexpMatch(".*get_host$")
      ) or
      (
        // request.META["HTTP_HOST"]
        e instanceof python.Subscript and
        e.getBase().toString().regexpMatch(".*request\\.META$") and
        e.getIndex().toString().regexpMatch(".*HTTP_HOST.*")
      )
      | source.asExpr() = e
    )
  }

  override predicate isSink(DataFlow::Node sink) {
    exists(python.Call call |
      (
        call.getCallee().toString().regexpMatch(".*send_email$") or
        call.getCallee().toString().regexpMatch(".*send_mail$") or
        call.getCallee().toString().regexpMatch(".*EmailMessage$") or
        call.getCallee().toString().regexpMatch(".*mail\\.send$")
      )
      | sink.asExpr() = call.getArgument(0)
    )
  }

  override predicate isSanitizer(DataFlow::Node node) {
    exists(python.Call call |
      (
        // validate_host(...)
        call.getCallee().toString().regexpMatch(".*validate_host.*") or
        // re.match/regex
        call.getCallee().toString().regexpMatch(".*re\\.match$") or
        call.getCallee().toString().regexpMatch(".*re\\.search$") or
        // startswith
        call.getCallee().toString().regexpMatch(".*startswith$")
      )
      | node.asExpr() = call.getArgument(0)
    ) or
    exists(python.Compare cmp |
      // host in ALLOWED_HOSTS
      cmp.getLeft().toString().regexpMatch(".*host$") and
      cmp.getRight().toString().regexpMatch(".*ALLOWED_HOSTS.*")
      | node.asExpr() = cmp.getLeft()
    )
  }
}

from DataFlow::PathNode source, DataFlow::PathNode sink, HNPTaintConfig cfg
where cfg.hasFlowPath(source, sink)
select
  sink.getNode().getFile(),
  sink.getNode().getLocation().getStartLine(),
  source.getNode().getFile(),
  source.getNode().getLocation().getStartLine(),
  source, sink,
  exists(DataFlow::PathNode n | cfg.isSanitizer(n.getNode())) ? "Sanitized" : "Not Sanitized" 