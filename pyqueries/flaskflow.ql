/**
 * @name Flask url_for(_external=True) Host Name Pollution
 * @description Absolute URLs built via url_for(..., _external=True) may rely on untrusted Host/X-Forwarded-Host.
 * @kind path-problem
 * @id py/flask/external-url-for-hnp
 * @problem.severity warning
 * @security-severity 8.0
 * @tags security
 *       framework/flask
 *       external/cwe/cwe-640
 */

import python
import semmle.python.dataflow.new.TaintTracking

/** recognize `request` or `flask.request` */
class FlaskRequestExpr extends Expr {
  FlaskRequestExpr() {
    // from flask import request
    exists(Name n | n = this and n.getId() = "request")
    or
    // import flask; flask.request
    exists(Attr a, Name base |
      a = this and a.getAttr() = "request" and base = a.getBase() and base.getId() = "flask"
    )
  }
}

/** request.host / request.host_url / request.url_root */
class HostAttrRead extends Expr {
  HostAttrRead() {
    exists(Attr a, FlaskRequestExpr r |
      a = this and a.getBase() = r and a.getAttr() in ["host","host_url","url_root"]
    )
  }
}

/** request.headers["Host"] / ["X-Forwarded-Host"] (case-insensitive) */
class HostHeaderRead extends Expr {
  HostHeaderRead() {
    exists(FlaskRequestExpr r, Attr headers, Subscript sub, Expr idx, Str s |
      sub = this and headers = sub.getBase() and headers.getBase() = r and headers.getAttr() = "headers" and
      idx = sub.getIndex() and s = idx and
      s.getValue().matches("(?i)^(host|x-forwarded-host)$")
    )
  }
}

/** calls to url_for(..., _external=...) or flask.url_for(..., _external=...) */
class UrlForExternalCall extends Call {
  UrlForExternalCall() {
    // callee name
    (
      exists(Name n | n = this.getFuncExpr() and n.getId() = "url_for") or
      exists(Attr a, Name base |
        a = this.getFuncExpr() and a.getAttr() = "url_for" and base = a.getBase() and base.getId() = "flask"
      )
    )
    and
    // has keyword `_external` (value不强行判断True，保守起见只要出现就告警；需要更严才加判断)
    exists(Argument kw | kw = this.getAnArg() and kw.getKeyword() = "_external")
  }
}

/** Taint configuration */
class HnpConfig extends TaintTracking::Configuration {
  HnpConfig() { this = "FlaskUrlForExternalHNP" }

  override predicate isSource(Node src) {
    exists(Expr e |
      e = src.asExpr() and
      ( e instanceof HostAttrRead or e instanceof HostHeaderRead )
    )
  }

  override predicate isSink(Node snk) {
    exists(Call c | c = snk.asExpr() and c instanceof UrlForExternalCall)
  }

  /**
   * Bridge read->call inside the same view function to surface a path.
   * （因为 request.host 与 url_for() 之间没有真实数据流关系）
   */
  override predicate isAdditionalFlowStep(Node from, Node to) {
    exists(Expr h, Call c, Function f |
      h = from.asExpr() and c = to.asExpr() and
      ( h instanceof HostAttrRead or h instanceof HostHeaderRead ) and
      c instanceof UrlForExternalCall and
      f = h.getEnclosingFunction() and f = c.getEnclosingFunction()
    )
  }
}

from HnpConfig cfg, Node src, Node sink
where cfg.hasFlowPath(src, sink)
select sink, src, sink,
  "Absolute URL derives from untrusted Host/X-Forwarded-Host via url_for(_external=...)."
