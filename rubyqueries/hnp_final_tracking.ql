/**
 * @name Final Ruby HNP Taint Tracking
 * @description Detect Host Header Pollution using Global Taint Tracking in Ruby
 * @kind problem
 * @problem.severity warning
 * @id ruby/hnp-final-tracking
 */

import codeql.ruby.DataFlow
import codeql.ruby.TaintTracking
import codeql.ruby.ApiGraphs

module HNPRubyConfiguration implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    // Request host sources
    exists(DataFlow::CallNode call |
      call = source and
      (
        // request.host
        call.getCalleeName() = "host" and
        exists(DataFlow::CallNode receiver |
          receiver = call.getReceiver() and
          receiver.getCalleeName() = "request"
        )
        or
        // request.env["HTTP_X_FORWARDED_HOST"]
        call.getCalleeName() = "[]" and
        exists(DataFlow::CallNode receiver |
          receiver = call.getReceiver() and
          receiver.getCalleeName() = "env" and
          exists(DataFlow::CallNode envReceiver |
            envReceiver = receiver.getReceiver() and
            envReceiver.getCalleeName() = "request"
          )
        ) and
        exists(StringLiteral sl |
          sl = call.getArgument(0) and
          (sl.getValue() = "HTTP_X_FORWARDED_HOST" or sl.getValue() = "X-Forwarded-Host")
        )
        or
        // request.env["HTTP_HOST"]
        call.getCalleeName() = "[]" and
        exists(DataFlow::CallNode receiver |
          receiver = call.getReceiver() and
          receiver.getCalleeName() = "env" and
          exists(DataFlow::CallNode envReceiver |
            envReceiver = receiver.getReceiver() and
            envReceiver.getCalleeName() = "request"
          )
        ) and
        exists(StringLiteral sl |
          sl = call.getArgument(0) and
          sl.getValue() = "HTTP_HOST"
        )
      )
    )
  }

  predicate isSink(DataFlow::Node sink) {
    // Email sending sinks
    exists(DataFlow::CallNode call |
      call = sink and
      (
        // send_reset_email function calls
        call.getCalleeName() = "send_reset_email"
        or
        // Net::SMTP.send_message
        call.getCalleeName() = "send_message" and
        exists(DataFlow::CallNode receiver |
          receiver = call.getReceiver() and
          receiver.getCalleeName() = "smtp"
        )
        or
        // Template rendering
        call.getCalleeName() = "render"
        or
        call.getCalleeName() = "erb"
        or
        // URL building
        call.getCalleeName() = "url_for"
        or
        call.getCalleeName() = "reset_password_url"
      )
    )
  }
}

module HNPRubyFlow = TaintTracking::Global<HNPRubyConfiguration>;

from DataFlow::Node source, DataFlow::Node sink
where HNPRubyFlow::flow(source, sink)
select source, "HNP Vulnerability: Request header flows to sensitive sink", sink, sink.toString()
