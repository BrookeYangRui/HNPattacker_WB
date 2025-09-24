/**
 * @name Comprehensive JavaScript HNP Detection
 * @description Comprehensive detection of Host Header Pollution vulnerabilities in JavaScript/Node.js applications
 * @kind problem
 * @problem.severity warning
 * @id js/comprehensive-hnp-detection
 */

import javascript

from Expr expr
where
  // Host sources - all possible host-related headers and properties
  (exists(Identifier id | id = expr and (
    id.getName() = "host" or 
    id.getName() = "hostname" or
    id.getName() = "hostname" or
    id.getName() = "hostHeader" or
    id.getName() = "serverName"
  ))) or
  
  // Header access patterns
  (exists(StringLiteral sl | sl = expr and (
    sl.getValue() = "host" or
    sl.getValue() = "hostname" or
    sl.getValue() = "x-forwarded-host" or
    sl.getValue() = "x-forwarded-for" or
    sl.getValue() = "x-real-ip" or
    sl.getValue() = "x-forwarded-proto" or
    sl.getValue() = "cf-connecting-ip" or
    sl.getValue() = "cf-ray" or
    sl.getValue() = "cf-ipcountry" or
    sl.getValue() = "user-agent" or
    sl.getValue() = "via" or
    sl.getValue() = "x-forwarded-server" or
    sl.getValue() = "x-original-host"
  ))) or
  
  // Email sending functions
  (exists(CallExpr call | call = expr and (
    call.getCalleeName() = "sendMail" or
    call.getCalleeName() = "sendResetEmail" or
    call.getCalleeName() = "createTransporter" or
    call.getCalleeName() = "send" or
    call.getCalleeName() = "sendMessage" or
    call.getCalleeName() = "sendEmail"
  ))) or
  
  // Template rendering functions
  (exists(CallExpr call | call = expr and (
    call.getCalleeName() = "render" or
    call.getCalleeName() = "renderTemplate" or
    call.getCalleeName() = "renderView" or
    call.getCalleeName() = "renderString" or
    call.getCalleeName() = "renderFile"
  ))) or
  
  // Template string operations
  (exists(CallExpr call | call = expr and (
    call.getCalleeName() = "replace" and
    exists(Identifier obj | obj = call.getReceiver() and
      (obj.getName() = "template" or obj.getName() = "html" or obj.getName() = "body")
    )
  ))) or
  
  // URL building patterns
  (exists(StringLiteral str | str = expr and (
    str.getValue() = "http://" or 
    str.getValue() = "https://" or
    str.getValue() = "ftp://" or
    str.getValue() = "ws://" or
    str.getValue() = "wss://"
  ))) or
  
  // Response header setting
  (exists(CallExpr call | call = expr and (
    call.getCalleeName() = "setHeader" or
    call.getCalleeName() = "header" or
    call.getCalleeName() = "set" or
    call.getCalleeName() = "type"
  ))) or
  
  // HTML content generation
  (exists(Identifier id | id = expr and (
    id.getName() = "html" or
    id.getName() = "htmlBody" or
    id.getName() = "body" or
    id.getName() = "content" or
    id.getName() = "template"
  ))) or
  
  // Context pollution patterns
  (exists(Identifier id | id = expr and (
    id.getName() = "globalContext" or
    id.getName() = "app" or
    id.getName() = "context" or
    id.getName() = "state" or
    id.getName() = "locals"
  )))
select expr, "HNP Component Found: $@", expr, "component"
