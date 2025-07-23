/**
 * @name Host Name Pollution (HNP) via Host Header in Email URLs
 * @description 检测攻击者可控的 Host 头部流入邮件发送 URL 的路径，防止主机头注入和钓鱼攻击。
 * @kind path-problem
 * @problem.severity warning
 * @id py/hnp-host-header-injection
 */

import python
import codeql.python.dataflow.TaintTracking

/**
 * 1. 定义 Source：攻击者可控的 Host 来源
 */
class HostHeaderSource extends TaintTracking::Source {
  HostHeaderSource() {
    exists(Call call |
      // Flask: request.headers['Host']
      call.getCallee().(AttributeAccess).getAttribute() = "headers" and
      call.getArgument(0).(StringLiteral).getStringValue() = "Host"
    )
    or
    exists(AttributeAccess attr |
      // Flask: request.host
      attr.getAttribute() = "host"
    )
    or
    exists(Call call |
      // Django: request.get_host()
      call.getCallee().(AttributeAccess).getAttribute() = "get_host"
    )
    or
    exists(IndexAccess idx |
      // Django: request.META['HTTP_HOST']
      idx.getIndex().(StringLiteral).getStringValue() = "HTTP_HOST"
    )
    or
    exists(Call call |
      // FastAPI: request.headers.get("host")
      call.getCallee().(AttributeAccess).getAttribute() = "get" and
      call.getArgument(0).(StringLiteral).getStringValue().toLowerCase() = "host"
    )
    or
    exists(AttributeAccess attr |
      // FastAPI: request.client.host
      attr.getAttribute() = "host" and
      attr.getQualifier() instanceof AttributeAccess and
      attr.getQualifier().(AttributeAccess).getAttribute() = "client"
    )
  }

  override string toString() { result = "Host header source" }
}

/**
 * 2. 定义 Sink：邮件发送相关函数
 */
class EmailSink extends TaintTracking::Sink {
  EmailSink() {
    exists(Call call |
      // send_email, send_mail, mail.send, EmailMessage, BackgroundTasks.add_task
      (
        call.getCallee().getName() = "send_email" or
        call.getCallee().getName() = "send_mail" or
        call.getCallee().getName() = "mail.send" or
        call.getCallee().getName() = "EmailMessage" or
        (
          call.getCallee().getName() = "add_task" and
          exists(Expr arg | call.getArgument(0) = arg and arg.toString().regexpMatch("send_email"))
        )
      )
    )
  }

  override string toString() { result = "Email sending sink" }
}

/**
 * 3. 配置污点追踪
 */
class HNPConfig extends TaintTracking::Configuration {
  HNPConfig() { this = "HNPConfig" }

  override predicate isSource(DataFlow::Node source) {
    source.asExpr() instanceof HostHeaderSource
  }

  override predicate isSink(DataFlow::Node sink) {
    sink.asExpr() instanceof EmailSink
  }

  // 允许通过 URL 构建函数传播
  override predicate isAdditionalTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
    exists(Call call |
      call = succ.asExpr() and
      (
        // Flask: url_for(..., _external=True)
        call.getCallee().getName() = "url_for" and
        exists(Argument arg | arg.getName() = "_external" and arg.getValue().toString() = "True")
      )
      or
      // Django: request.build_absolute_uri(...)
      call.getCallee().(AttributeAccess).getAttribute() = "build_absolute_uri"
    )
  }
}

/**
 * 4. 查询主逻辑
 */
from HostHeaderSource source, EmailSink sink, HNPConfig config, TaintTracking::PathNode path
where config.hasFlowPath(source, sink, path)
select sink, source, path, "Host header value flows into email sending function, possible HNP vulnerability."