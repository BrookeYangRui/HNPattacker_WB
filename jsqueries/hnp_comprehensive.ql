/**
 * @name JavaScript HNP Comprehensive Taint Tracking
 * @description Tracks attacker-controlled host/proto/origin data to sensitive sinks across Express/Koa/NestJS/Hapi.
 * @kind path-problem
 * @problem.severity warning
 * @id js/hnp-comprehensive-taint
 */

import javascript
import DataFlow
import DataFlow::PathGraph

class Config extends TaintTracking::Configuration {
    Config() { this = "js-hnp-config" }

    /** Sources: Host/Proto/Origin/URL getters across Express/Koa/NestJS/Hapi */
    override predicate isSource(DataFlow::Node source) {
        // 1) Header/API getters like req.get('host'), req.header('x-forwarded-proto')
        exists(CallExpr c, StringLiteral s |
            source.asExpr() = c and
            c.getCalleeName() in ["get", "header", "headers"] and
            s = c.getArgument(0) and s.getStringValue() in [
                "host", "Host",
                "x-forwarded-host", "X-Forwarded-Host",
                "x-forwarded-proto", "X-Forwarded-Proto"
            ]
        ) or
        // 1.5) Cross-version-safe fallback handled below via toString() pattern matching
        // 2) Structural string-pattern fallback for property access (cross-version safe)
        exists(Expr e |
            source.asExpr() = e and
            (
                // req.headers.host / req.headers['host'] / ctx.request.headers['host']
                e.toString().regexpMatch("\\.headers\\.host\\b") or
                e.toString().regexpMatch("\\.headers\\\\\\['host'\\\\\\]") or
                e.toString().regexpMatch("request\\.host\\b") or
                e.toString().regexpMatch("hostname\\b") or
                e.toString().regexpMatch("protocol\\b") or
                e.toString().regexpMatch("baseUrl\\b") or
                e.toString().regexpMatch("originalUrl\\b") or
                e.toString().regexpMatch("ctx\\.origin\\b") or
                e.toString().regexpMatch("ctx\\.href\\b") or
                e.toString().regexpMatch("(res|response|app)\\.locals\\.") or
                e.toString().regexpMatch("ctx\\.state\\.") or
                e.toString().regexpMatch("reply\\.request\\.hostname|reply\\.request\\.headers\\.host") or
                e.toString().regexpMatch("info\\.host\\b") or
                e.toString().regexpMatch("info\\.protocol\\b") or
                e.toString().regexpMatch("info\\.uri\\b") or
                e.toString().regexpMatch("request\\.url|request\\.info\\.uri|request\\.raw\\.req\\.headers\\.host") or
                e.toString().regexpMatch("x-forwarded-host") or
                e.toString().regexpMatch("x-forwarded-proto")
            )
        ) or
        // 3) Heuristic variable names used as host containers
        exists(Identifier id |
            source.asExpr() = id and id.getName() in ["host", "hostname", "origin", "proto", "protocol"]
        )
    }

    /** Sinks: Redirects, Location headers, email/html/url builders */
    override predicate isSink(DataFlow::Node sink) {
        exists(CallExpr c, Expr a |
            a = c.getAnArgument() and sink.asExpr() = a and (
                // 1) Redirect APIs (Express/Koa/Nest/Fastify/Hapi wraps)
                c.getCalleeName() in ["redirect", "location", "permanentRedirect"] or
                // 2) Setting Location header
                (
                    c.getCalleeName() in ["set", "header", "setHeader"] and
                    exists(StringLiteral name | name = c.getArgument(0) and name.getStringValue() = "Location" and a = c.getArgument(1))
                ) or
                // 2.5) Password reset helper: only second argument is html
                (c.getCalleeName() = "sendResetEmail" and a = c.getArgument(1)) or
                // 3) Mailing helpers (password reset / activation)
                c.getCalleeName() in ["sendMail", "sendEmail", "send_message", "sendMessage", "sendResetEmail", "createTransport", "createTransporter"] or
                // 4) URL builder helpers frequently used by apps
                c.getCalleeName() in ["buildUrl", "generateUrl", "absoluteUrl", "urlFor", "routeUrl", "format", "formatUrl", "formatURL", "url", "formatURLToString"]
            )
        )
        or
        // Structural string-pattern fallback for method-style sinks (version-safe)
        exists(Expr e |
            sink.asExpr() = e and (
                e.toString().regexpMatch("\\bredirect\\s*\\(|reply\\.redirect\\s*\\(|h\\.redirect\\s*\\(") or
                e.toString().regexpMatch("\\bset(Header)?\\s*\\(\\s*['\" ]Location['\" ]") or
                e.toString().regexpMatch("\\bsendMail\\s*\\(|\\.sendMail\\s*\\(") or
                e.toString().regexpMatch("\\bsendResetEmail\\s*\\(") or
                e.toString().regexpMatch("generateUrl|absoluteUrl|urlFor|routeUrl|router\\.url\\s*\\(|url\\.format\\s*\\(|new URL\\s*\\(|toString\\s*\\(|res\\.location\\s*\\(|reply\\.header\\s*\\(|h\\.response\\s*\\(")
            )
        )
    }

    /** Additional taint: string ops, template literals, URL constructors/helpers, common utils */
    override predicate isAdditionalTaintStep(DataFlow::Node pred, DataFlow::Node succ) {
        // Concatenation a + b
        exists(BinaryExpr add |
            add.getOperator() = "+" and pred.asExpr() = add.getAnOperand() and succ.asExpr() = add
        ) or
        // Template literals `${...}` → approximate by any call that returns a string from args
        // (TemplateLiteral type may not be available in older lib versions)
        // String replace helpers
        exists(CallExpr c |
            c.getCalleeName() in ["replace", "concat", "join", "format"] and pred.asExpr() = c.getAnArgument() and succ.asExpr() = c
        ) or
        // URL constructors and helpers: new URL(arg1, arg2), URL(arg1, arg2), url.resolve(base, to)
        exists(NewExpr ne |
            ne.getCalleeName() = "URL" and pred.asExpr() = ne.getAnArgument() and succ.asExpr() = ne
        ) or
        exists(CallExpr c2 |
            c2.getCalleeName() in ["URL", "resolve", "format", "formatUrl", "formatURL"] and pred.asExpr() = c2.getAnArgument() and succ.asExpr() = c2
        ) or
        // util.format('%s', x)
        exists(CallExpr cu |
            cu.getCalleeName() = "format" and pred.asExpr() = cu.getAnArgument() and succ.asExpr() = cu
        ) or
        // Object/array joining & assignment helpers (approximate)
        exists(CallExpr ca |
            ca.getCalleeName() in ["assign", "push"] and pred.asExpr() = ca.getAnArgument() and succ.asExpr() = ca
        )
    }
}

from Config cfg, DataFlow::PathNode src, DataFlow::PathNode snk
where cfg.hasFlowPath(src, snk)
select snk, src, snk, "HNP: user-controlled host/proto/origin reaches sensitive sink"
