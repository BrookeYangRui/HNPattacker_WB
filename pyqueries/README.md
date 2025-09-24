# Python HNP Detection

HTTP Request Header Pollution (HNP) vulnerability detection for Python applications using CodeQL.

## Quick Start

Repository: `https://github.com/BrookeYangRui/HNPattacker_WB`

```bash
# 1) 安装 CodeQL CLI 并确保已创建 Python 数据库 py-db/pyexample-db
# 2) 安装查询依赖（一次性）
codeql pack install

# 3) 运行综合查询并输出分类结果
python run_analysis.py
```

Run the query directly (optional):
```bash
codeql query run hnp_comprehensive.ql --database ..\py-db\pyexample-db --output results.bqrs
codeql bqrs decode results.bqrs --format=text | more
```

## Files

- `hnp_comprehensive.ql` - Comprehensive CodeQL query using Global Taint Tracking
- `run_analysis.py` - Analysis script that runs query and summarizes results

## How It Works

### Source (数据源)
The query identifies request parameters as sources:
- `request` parameter in function definitions
- **Django**: `request.get_host()`, `request.build_absolute_uri()`, `request.META`, `request.headers`, `request.scheme`, `request.is_secure()`, `request.get_port()`, `request.environ`
- **Flask**: `request.host`, `request.url_root`, `request.base_url`, `request.headers`, `request.environ`
- **FastAPI/Starlette**: `request.url`, `request.base_url`, `request.client`, `request.headers`, `request.scope`
- **Tornado**: `request.host`, `request.full_url()`, `request.headers`
- **Pyramid**: `request.host_url`, `request.application_url`, `request.headers`
- **Bottle**: `request.url`, `request.headers`, `request.environ`
- **Sanic**: `request.url`, `request.headers`, `request.remote_addr`
- **Falcon**: `request.url`, `request.headers`, `request.remote_addr`
- **Web2py**: `request.url`, `request.headers`, `request.environ`

### Sink (数据汇)
The query identifies sensitive functions as sinks:
- **Mail sending**: `send_mail()`, `send_reset_email()`, `EmailMessage`, `EmailMultiAlternatives`
- **Redirects**: `redirect()`, `HttpResponseRedirect()`, `RedirectResponse()`, `HTTPFound`
- **Template rendering**: `render_template()`, `render()`, `render_to_string()`, `Template()`
- **URL generation**: `url_for()`, `reverse()`, `build_absolute_uri()`, `route_url()`
- **OAuth callbacks**: `oauth_callback()`, `callback()`, `authorize()`, `oauth_authorize()`
- **API docs**: `docs()`, `openapi()`, `swagger()`, `redoc()`, `swagger_ui()`
- **WebSocket**: `websocket()`, `WebSocket()`, `websocket_connect()`
- **Cache**: `cache()`, `set_cache()`, `cache_set()`, `cache_get()`
- **Session**: `session()`, `set_session()`, `session_set()`, `session_get()`
- **Logging**: `log()`, `logger()`, `info()`, `warning()`, `error()`, `debug()`
- **Django Admin**: `get_absolute_url()`, `get_admin_url()`, `get_site_url()`, `get_current_site()`, `admin_reverse()`
- **Django Auth**: `PasswordResetView`, `PasswordResetConfirmView`, `UserActivationView`, `UserRegistrationView`
- **Django Cache/Session**: `cache_set()`, `cache_get()`, `session_set()`, `set_cookie()`, `set_signed_cookie()`

### Flow Rules (数据流规则)
Uses CodeQL Global Taint Tracking to detect:
1. **Direct flows**: Request parameter → Sensitive function
2. **Indirect flows**: Request parameter → Variable → Sensitive function
3. **String operations**: Request parameter → String concatenation → Sensitive function
4. **Attribute access**: Request parameter → Attribute access → Sensitive function

## Framework-Specific HNP Patterns

### Django
**High-Risk Functions**: `request.get_host()`, `request.build_absolute_uri()`, `HttpResponseRedirect()`, `PasswordResetView`
**Common Scenarios**: Password reset emails, canonical URLs, redirects, admin URLs, cache poisoning
**Protection**: `ALLOWED_HOSTS` (whitelist validation), `USE_X_FORWARDED_HOST=False`, `is_safe_url` checks

**Complete API Coverage**:
- **Source APIs**: `environ['HTTP_HOST']` → `HttpRequest.get_host()` → `HttpRequest.build_absolute_uri()`
- **Sink APIs**: `reverse()`, `HttpResponseRedirect()`, `django.core.mail.send_mail()`, `PasswordResetView`
- **Admin Integration**: `get_absolute_url()`, `get_admin_url()`, `admin_reverse()`, `AdminSite`
- **Sites Integration**: `get_current_site()`, `get_site_url()`, `get_site()`
- **Cache/Session**: `cache_set()`, `session_set()`, `set_cookie()`, `set_signed_cookie()`

### Flask
**High-Risk Functions**: `url_for(..., _external=True)`, `redirect()`, `request.url_root`
**Common Scenarios**: Email links, OAuth callbacks, 302 redirects
**Protection**: `SERVER_NAME` (fixed domain), Nginx/Apache frontend restrictions, avoid `ProxyFix(x_host=1)`

- Sources: `environ['HTTP_HOST']`, `Request.host`, `Request.url_root`, `request.headers.get(...)`, `request.environ.get(...)`
- Sinks: `url_for(_external=True)`, `redirect(...)`, `mail.send(...)`, `mail.send_message(...)`
- Flow: Host → url_root/url_for → redirect/mail content → outward links
- Protection: Configure `SERVER_NAME`; avoid over-trusting ProxyFix / forwarded headers

### FastAPI / Starlette (Detailed)
**Problematic APIs (bottom → top)**
- `scope["headers"]` (ASGI): raw headers (attacker-controlled)
- `starlette.requests.Request.url`: full URL (from Host header)
- `starlette.requests.Request.base_url`: `scheme://host/` (from Host header)
- `app.url_path_for("route")`: path builder; joins with base_url
- `Request.url_for("route")`: absolute URL = base_url + url_path_for
- `starlette.responses.RedirectResponse(url)`: 302 redirect (often from `Request.url_for`)
- FastAPI Security/OAuth2Redirect: uses `request.url_for()` to build redirect_uri

**Sources**
- ASGI: `scope["headers"]` via `request.scope`
- Starlette/FastAPI: `request.url`, `request.base_url`, `request.url_for()` (base), `request.headers`

**Sinks**
- `RedirectResponse(...)`
- `request.url_for(...)` (absolute URL generation used downstream)
- OAuth2 flows (FastAPI security) that consume `redirect_uri`
- API docs absolute URLs (if constructed from request)

**Flow**
- Host / X-Forwarded-Host (if proxy trusted) → `Request.base_url` / `Request.url`
  → `Request.url_for("route")` = base_url + `app.url_path_for()`
  → `RedirectResponse` / OAuth2 redirect / links in emails or docs

**Protection**
- `forwarded_allow_ips`: restrict trusted proxies
- `root_path`: set external base path/domain when behind reverse proxy
- Prefer fixed external domain for absolute URL building

### Tornado
**Problematic APIs (bottom → top)**
- `HTTPRequest.headers["Host"]` (raw Host header)
- `HTTPRequest.host` (reads Host)
- `HTTPRequest.full_url()` = protocol + host + uri
- `RequestHandler.reverse_url()` joins with host to absolute URL
- `RequestHandler.redirect(url)` may form absolute URL if relative provided

**Sources**
- `request.host`, `request.full_url()`, `request.uri`, `request.protocol`, `request.headers`

**Sinks**
- `RequestHandler.redirect(...)`, `RequestHandler.reverse_url(...)`, `RequestHandler.write(...)`, `RequestHandler.render(...)`

**Flow**
- Host / X-Forwarded-Host (if proxy trusted) → `request.host` / `request.full_url()`
  → `reverse_url()` (path) + host → absolute URL
  → `redirect()` / OAuth / API links

**Protection**
- `Application(trusted_downstream=...)`: only trust specific proxies
- Prefer fixed external URL base for absolute URL building

### Pyramid
**Problematic APIs (bottom → top)**
- `environ["HTTP_HOST"]` (raw Host header)
- `pyramid.request.Request.host` (reads `HTTP_HOST`)
- `pyramid.request.Request.host_url` = `scheme://host[:port]`
- `pyramid.request.Request.application_url` = `host_url` + `script_name`
- `request.route_url("name")` depends on `request.host_url`
- `pyramid.httpexceptions.HTTPFound(location)` for redirects
- `pyramid_mailer` inserts absolute URLs into emails via `route_url`

**Sources**
- `request.host`, `request.host_url`, `request.application_url`, `request.headers`

**Sinks**
- `HTTPFound(...)`, `request.route_url(...)`, `render_to_response(...)`
- `pyramid_mailer`: `Mailer/Message`, `send`, `send_immediately`, `send_to_queue`

**Flow**
- Host header → `request.host` / `host_url` / `application_url`
  → `request.route_url("name")` → `HTTPFound` / email links / canonical URLs

**Protection**
- `trusted_hosts`: enable strict host whitelist
- Prefer fixed domain for absolute URLs

### Bottle
**Problematic APIs (bottom → top)**
- `environ["HTTP_HOST"]` (raw Host header)
- `bottle.request.url` (absolute URL based on Host)
- `bottle.request.headers` / `environ` access
- `bottle.redirect(url)` and `bottle.url(...)`

**Sources**
- `request.url`, `request.headers`, `request.environ`

**Sinks**
- `redirect(...)`, `url(...)`, `response` (Location header)

**Flow**
- Host header → `request.url` / `headers` / `environ` → `url(...)` → `redirect(...)` / absolute links

**Protection**
- Prefer fixed external base; validate `Host` before building absolute URLs

### Sanic
**Problematic APIs (bottom → top)**
- `environ["HTTP_HOST"]` / `request.headers` (raw Host)
- `request.url`
- `app.url_for(...)` (absolute URL with host)
- `sanic.response.redirect(...)`, `json/html/text` (links)

**Sources**
- `request.url`, `request.headers`, `request.remote_addr`

**Sinks**
- `redirect(...)`, `url_for(...)`, `json(...)`, `html(...)`, `text(...)`

**Flow**
- Host → `request.url` → `url_for(...)` → `redirect(...)` / links in responses

**Protection**
- Set external base; avoid trusting forwarded headers by default

### Falcon
**Problematic APIs (bottom → top)**
- `environ["HTTP_HOST"]` / `req.get_header("Host")`
- `req.url`
- `falcon.Response` with `location` or redirection classes: `HTTPFound`, `HTTPMovedPermanently`

**Sources**
- `request.url`, `request.headers`, `request.remote_addr`

**Sinks**
- `Response(...)`, `HTTPFound(...)`, `HTTPMovedPermanently(...)`

**Flow**
- Host → `req.url` → build redirect `location` → `HTTPFound`

**Protection**
- Fix external domain; do not derive from request Host in redirects

### Web2py
**Problematic APIs (bottom → top)**
- `environ["HTTP_HOST"]` / `request.env.http_host`
- `request.url`
- `URL(...)` (absolute URL builder)
- `redirect(URL(...))`

**Sources**
- `request.url`, `request.headers`, `request.environ`

**Sinks**
- `redirect(...)`, `URL(...)`, `response`

**Flow**
- Host → `request.url` → `URL(...)` → `redirect(...)` / email/templates

**Protection**
- Use configured domain for `URL(...)`; validate `Host`

## Runtime Classification

| Environment | Django | Flask | FastAPI/Starlette | Tornado | Pyramid |
|-------------|--------|-------|-------------------|---------|---------|
| **Direct Connection** | `get_host()` = Host header; Low risk | `request.host` trusts Host; High risk | `request.base_url` trusts Host; High risk | `request.host` trusts Host; High risk | `request.host_url` trusts Host; High risk |
| **Proxy → Untrusted** | Ignores `X-Forwarded-*`; may show internal addresses | Ignores forwarded; may show `http://127.0.0.1` | Ignores forwarded; internal address bug | Ignores forwarded; internal address bug | Ignores forwarded; internal address bug |
| **Proxy → Correctly Trusted** | `USE_X_FORWARDED_HOST=False`; only trust scheme; **Secure ✅** | Configure `SERVER_NAME` fixed; **Secure ✅** | Configure `forwarded_allow_ips=LB_IP` + fixed external URL; **Secure ✅** | `trusted_downstream=[LB_IP]`; **Secure ✅** | `trusted_hosts` fixed domain; **Secure ✅** |
| **Proxy → Mis-trusted** | `USE_X_FORWARDED_HOST=True` with no filtering → HNP high risk | `ProxyFix(x_host=1)` full trust → HNP high risk | `forwarded_allow_ips="*"` → HNP high risk | `trusted_downstream="*"` → HNP high risk | No `trusted_hosts` set or too broad → HNP high risk |

## Output

The analysis provides:
- Total number of HNP flows found
- Framework distribution
- Vulnerability scenario types
- Detailed flow examples

## Example Scenarios

- **Password Reset Attack**: `request.get_host()` → `send_mail()`
- **Open Redirect**: `request.host` → `redirect()`
- **Template Injection**: `request.url` → `render_template()`
- **URL Generation Attack**: `request.base_url` → `url_for()`