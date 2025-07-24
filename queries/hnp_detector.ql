/**
 * Host Name Pollution (HNP) 检测器
 * 标记 Host 头访问为 taint source，跟踪到敏感 sink，检测净化逻辑
 */
import python
import semmle.python.dataflow.new.TaintTracking

class HNPTaintConfig extends TaintTracking::Configuration {
  HNPTaintConfig() { this = "HNPTaintConfig" }

  override predicate isSource(DataFlow::Node source) {
    exists(Subscript s |
      s = source.asExpr() and
      s.getBase().toString().regexpMatch(".*request\\.headers$") and
      s.getIndex().toString().regexpMatch(".*Host.*")
    )
    or
    exists(Call c |
      c = source.asExpr() and
      c.getCallee().toString().regexpMatch(".*get_host$")
    )
    or
    exists(Subscript s |
      s = source.asExpr() and
      s.getBase().toString().regexpMatch(".*request\\.META$") and
      s.getIndex().toString().regexpMatch(".*HTTP_HOST.*")
    )
  }

  override predicate isSink(DataFlow::Node sink) {
    exists(Call c |
      c.getArgument(0) = sink.asExpr() and
      (
        c.getCallee().toString().regexpMatch(".*send_email$") or
        c.getCallee().toString().regexpMatch(".*send_mail$") or
        c.getCallee().toString().regexpMatch(".*EmailMessage$") or
        c.getCallee().toString().regexpMatch(".*mail\\.send$")
      )
    )
  }

  override predicate isSanitizer(DataFlow::Node node) {
    exists(Call c |
      c.getArgument(0) = node.asExpr() and
      (
        c.getCallee().toString().regexpMatch(".*validate_host.*") or
        c.getCallee().toString().regexpMatch(".*re\\.match$") or
        c.getCallee().toString().regexpMatch(".*re\\.search$") or
        c.getCallee().toString().regexpMatch(".*startswith$")
      )
    )
    or
    exists(Compare cmp |
      cmp.getLeft() = node.asExpr() and
      cmp.getLeft().toString().regexpMatch(".*host$") and
      cmp.getRight().toString().regexpMatch(".*ALLOWED_HOSTS.*")
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
  source.getNode().toString(),
  sink.getNode().toString(),
  exists(DataFlow::PathNode n | cfg.isSanitizer(n.getNode())) ? "Sanitized" : "Not Sanitized" 