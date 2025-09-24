/**
 * @name Ruby HNP Component Detection
 * @description Detect Host Header Pollution components in Ruby
 * @kind problem
 * @problem.severity warning
 * @id ruby/hnp-component-detection
 */

import ruby

from CallExpr call
where
  // Host sources
  (call.getMethodName() = "host" and
   exists(CallExpr receiver |
     receiver = call.getReceiver() and
     receiver.getMethodName() = "request"
   ))
  or
  (call.getMethodName() = "[]" and
   exists(CallExpr receiver |
     receiver = call.getReceiver() and
     receiver.getMethodName() = "env" and
     exists(CallExpr envReceiver |
       envReceiver = receiver.getReceiver() and
       envReceiver.getMethodName() = "request"
     )
   ) and
   exists(StringLiteral sl |
     sl = call.getArgument(0) and
     (sl.getValue() = "HTTP_X_FORWARDED_HOST" or sl.getValue() = "HTTP_HOST")
   ))
  or
  // Email sinks
  call.getMethodName() = "send_reset_email"
  or
  (call.getMethodName() = "send_message" and
   exists(CallExpr receiver |
     receiver = call.getReceiver() and
     receiver.getMethodName() = "smtp"
   ))
  or
  // Template rendering
  call.getMethodName() = "render"
  or
  call.getMethodName() = "erb"
  or
  // URL building
  call.getMethodName() = "url_for"
  or
  call.getMethodName() = "reset_password_url"
select call, "HNP Component Found: $@", call, "component"
