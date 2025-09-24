/**
 * @name Comprehensive Python HNP Detection
 * @description Comprehensive HNP detection for all Python web frameworks
 * @kind problem
 * @problem.severity warning
 * @id py/hnp-comprehensive
 */

import python
import semmle.python.dataflow.new.DataFlow
import semmle.python.dataflow.new.TaintTracking

module HNPComprehensiveConfiguration implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    // Request parameter as source
    exists(DataFlow::ParameterNode param |
      param = source and
      param.getParameter().getName() = "request"
    )
    or
    // Django host sources
    exists(Call call |
      call = source.asExpr() and
      (exists(Attribute af | af = call.getFunc() and (
        af.getAttr() = "get_host" or
        af.getAttr() = "build_absolute_uri" or
        af.getAttr() = "get_full_path" or
        af.getAttr() = "get_raw_uri" or
        af.getAttr() = "get_absolute_uri" or
        af.getAttr() = "META" or
        af.getAttr() = "headers" or
        af.getAttr() = "scheme" or
        af.getAttr() = "is_secure" or
        af.getAttr() = "get_port"
      )))
    )
    or
    // Django environ access
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "environ" or
       attr.getAttr() = "META")
    )
    or
    // Explicit forwarded header sources via *.get(...)
    exists(Call call, Attribute getFunc |
      call = source.asExpr() and
      getFunc = call.getFunc() and
      getFunc.getAttr() = "get"
    )
    or
    // Explicit header keys (Host / X-Forwarded-*) to strengthen signal
    exists(Call call, Attribute getFunc, Expr key |
      call = source.asExpr() and
      getFunc = call.getFunc() and
      getFunc.getAttr() = "get" and
      key = call.getArg(0) and
      (
        key.toString() = "\"host\"" or
        key.toString() = "\"Host\"" or
        key.toString() = "\"HTTP_HOST\"" or
        key.toString() = "\"SERVER_NAME\"" or
        key.toString() = "\"SERVER_PORT\"" or
        key.toString() = "\"wsgi.url_scheme\"" or
        key.toString() = "\"x-forwarded-host\"" or
        key.toString() = "\"X-Forwarded-Host\"" or
        key.toString() = "\"x-forwarded-proto\"" or
        key.toString() = "\"X-Forwarded-Proto\"" or
        key.toString() = "\"forwarded\"" or
        key.toString() = "\"Forwarded\""
      )
    )
    or
    // Flask host sources
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "host" or
       attr.getAttr() = "url_root" or
       attr.getAttr() = "base_url" or
       attr.getAttr() = "url" or
       attr.getAttr() = "remote_addr" or
       attr.getAttr() = "headers" or
       attr.getAttr() = "environ")
    )
    or
    // FastAPI/Starlette host sources
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "url" or
       attr.getAttr() = "base_url" or
       attr.getAttr() = "client" or
       attr.getAttr() = "headers" or
       attr.getAttr() = "scope")
    )
    or
    // Tornado host sources
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "host" or
       attr.getAttr() = "full_url" or
       attr.getAttr() = "uri" or
       attr.getAttr() = "remote_ip" or
       attr.getAttr() = "headers")
    )
    or
    // Tornado explicit request attribute sources
    exists(Attribute attr |
      attr = source.asExpr() and (
        attr.getAttr() = "host" or
        attr.getAttr() = "full_url" or
        attr.getAttr() = "uri" or
        attr.getAttr() = "protocol"
      )
    )
    or
    // Pyramid host sources
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "host_url" or
       attr.getAttr() = "application_url" or
       attr.getAttr() = "url" or
       attr.getAttr() = "remote_addr" or
       attr.getAttr() = "headers" or
       attr.getAttr() = "host"
      )
    )
    or
    // Bottle host sources
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "url" or
       attr.getAttr() = "headers" or
       attr.getAttr() = "environ")
    )
    or
    // Sanic host sources
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "url" or
       attr.getAttr() = "headers" or
       attr.getAttr() = "remote_addr")
    )
    or
    // Falcon host sources
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "url" or
       attr.getAttr() = "headers" or
       attr.getAttr() = "remote_addr")
    )
    or
    // Web2py host sources
    exists(Attribute attr |
      attr = source.asExpr() and
      (attr.getAttr() = "url" or
       attr.getAttr() = "headers" or
       attr.getAttr() = "environ")
    )
    or
    // Environment variables and headers
    exists(Call call |
      call = source.asExpr() and
      (exists(Name n | n = call.getFunc() and (
        n.getId() = "getenv" or
        n.getId() = "environ"
      )))
    )
  }

  // Additional taint steps: dictionary get and string format
  predicate isAdditionalFlowStep(DataFlow::Node a, DataFlow::Node b) {
    // dict.get(...) : arguments taint flows to return value (approximate)
    exists(Call call, Attribute f |
      call = b.asExpr() and
      f = call.getFunc() and
      f.getAttr() = "get" and
      a.asExpr() = call.getAnArg()
    )
    or
    // str.format(...): arguments taint flows to return value (approximate)
    exists(Call call, Attribute f |
      call = b.asExpr() and
      f = call.getFunc() and
      f.getAttr() = "format" and
      a.asExpr() = call.getAnArg()
    )
  }

  predicate isSink(DataFlow::Node sink) {
    // Generic: treat function arguments as sinks for sensitive APIs
    exists(Call call, Expr arg |
      arg = sink.asExpr() and
      arg = call.getAnArg() and (
        // By function name
        exists(Name n | n = call.getFunc() and (
          n.getId() = "send_mail" or 
          n.getId() = "send_reset_email" or
          n.getId() = "send" or
          n.getId() = "send_message" or
          n.getId() = "send_email" or
          n.getId() = "EmailMessage" or
          n.getId() = "EmailMultiAlternatives" or
          n.getId() = "render_template" or
          n.getId() = "render_template_string" or
          n.getId() = "render" or
          n.getId() = "render_to_string" or
          n.getId() = "render_to_response" or
          n.getId() = "Template" or
          n.getId() = "HttpResponseRedirect" or
          n.getId() = "HttpResponsePermanentRedirect" or
          n.getId() = "redirect" or
          n.getId() = "reverse" or
          n.getId() = "reverse_lazy" or
          n.getId() = "resolve_url" or
          n.getId() = "RedirectResponse" or
          n.getId() = "HTTPFound" or
          n.getId() = "Response" or
          n.getId() = "JSONResponse" or
          n.getId() = "HTMLResponse" or
          n.getId() = "HTTPMovedPermanently" or
          n.getId() = "URL" or
          n.getId() = "get_current_site" or
          n.getId() = "Site" or
          n.getId() = "each_context" or
          n.getId() = "LoginView" or
          n.getId() = "LogoutView" or
          n.getId() = "PasswordChangeView" or
          n.getId() = "get_redirect_uri" or
          n.getId() = "build_absolute_uri"
        ))
        or
        // By attribute: method-style sinks (e.g., request.route_url, app.url_path_for)
        exists(Attribute af | af = call.getFunc() and (
          af.getAttr() = "build_absolute_uri" or
          af.getAttr() = "reverse" or
          af.getAttr() = "url_for" or
          af.getAttr() = "reverse_url" or
          af.getAttr() = "route_url" or
          af.getAttr() = "full_url" or
          af.getAttr() = "absolute_url" or
          af.getAttr() = "get_absolute_url" or
          af.getAttr() = "url_path_for" or
          af.getAttr() = "send" or
          af.getAttr() = "send_message"
        ))
      )
    )
    or
    // Mail sending sinks (call-level, retained for completeness)
    exists(Call call |
      call = sink.asExpr() and
      (exists(Name n | n = call.getFunc() and (
        n.getId() = "send_mail" or 
        n.getId() = "send_reset_email" or
        n.getId() = "send" or
        n.getId() = "send_message" or
        n.getId() = "send_email" or
        n.getId() = "mail" or
        n.getId() = "EmailMessage" or
        n.getId() = "EmailMultiAlternatives"
      )))
      or
      (exists(Attribute a | a = call.getFunc() and (
        a.getAttr() = "send" or
        a.getAttr() = "send_message"
      )))
    )
    or
    // Template rendering sinks (call-level)
    exists(Call call |
      call = sink.asExpr() and
      (exists(Name n | n = call.getFunc() and (
        n.getId() = "render_template" or
        n.getId() = "render_template_string" or
        n.getId() = "render" or
        n.getId() = "render_to_string" or
        n.getId() = "render_to_response" or
        n.getId() = "Template" or
        n.getId() = "render_string"
      )))
    )
    or
    // Redirect / URL sinks (call-level)
    exists(Call call |
      call = sink.asExpr() and
      (exists(Name n | n = call.getFunc() and (
        n.getId() = "HttpResponseRedirect" or
        n.getId() = "HttpResponsePermanentRedirect" or
        n.getId() = "redirect" or
        n.getId() = "reverse" or
        n.getId() = "reverse_lazy" or
        n.getId() = "resolve_url" or
        n.getId() = "RedirectResponse" or
        n.getId() = "HTTPFound" or
        n.getId() = "Response" or
        n.getId() = "JSONResponse" or
        n.getId() = "HTMLResponse" or
        n.getId() = "HTTPMovedPermanently" or
        n.getId() = "URL"
      )))
      or
      exists(Attribute af | af = call.getFunc() and (
        af.getAttr() = "build_absolute_uri" or
        af.getAttr() = "reverse" or
        af.getAttr() = "url_for" or
        af.getAttr() = "reverse_url" or
        af.getAttr() = "route_url" or
        af.getAttr() = "full_url" or
        af.getAttr() = "absolute_url" or
        af.getAttr() = "get_absolute_url" or
        af.getAttr() = "url_path_for"
      ))
    )
    or
    // OAuth callback sinks (call-level)
    exists(Call call |
      call = sink.asExpr() and
      (exists(Name n | n = call.getFunc() and (
        n.getId() = "oauth_callback" or
        n.getId() = "callback" or
        n.getId() = "authorize" or
        n.getId() = "oauth_authorize" or
        n.getId() = "oauth_token" or
        n.getId() = "oauth_access_token"
      )))
    )
    or
    // API documentation sinks (call-level)
    exists(Call call |
      call = sink.asExpr() and
      (exists(Name n | n = call.getFunc() and (
        n.getId() = "docs" or
        n.getId() = "openapi" or
        n.getId() = "swagger" or
        n.getId() = "redoc" or
        n.getId() = "swagger_ui" or
        n.getId() = "get_openapi"
      )))
    )
  }
}

module HNPComprehensiveFlow = TaintTracking::Global<HNPComprehensiveConfiguration>;

from DataFlow::Node source, DataFlow::Node sink
where HNPComprehensiveFlow::flow(source, sink)
select source, "HNP Vulnerability: Request parameter flows to sensitive sink {1}", sink, sink.toString()
