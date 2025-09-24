# Java HNP Detection (Global Taint Tracking)

本目录提供 Java 版 HNP（Host Header Pollution）综合污点追踪查询与文档。

## 快速开始

```bash
codeql pack install
codeql query run javaqueries/hnp_comprehensive.ql --database java-db/javaexample-db --output java-hnp.bqrs
codeql bqrs decode java-hnp.bqrs --format=text | more
```

## 查询文件

- `hnp_comprehensive.ql`（主查询）: 使用 `TaintTracking::Global`，跟踪 Host 源 → 传播 → 敏感汇点
- 补充（保留）: `hnp_component_detection.ql` 等旧查询

## 设计概览

- **Source（源）**：
  - Servlet/Jakarta: `HttpServletRequest.getHeader("Host"|"X-Forwarded-Host"|"X-Forwarded-Proto"|"Forwarded")`, `getServerName/Port/Scheme`, `getRequestURL/URI`
  - Spring: `ServletUriComponentsBuilder.fromCurrentRequest*`, `fromCurrentContextPath`, HATEOAS `WebMvcLinkBuilder.linkTo(...)`
  - Struts2: `UrlHelper.buildUrl(...)`
  - Play: `Call.absoluteURL(request)`

- **Additional Flow（额外传播）**：
  - `Map.get` / `HttpHeaders.getFirst`
  - `StringBuilder.append` / `String.format`
  - `UriComponentsBuilder` 链式构建

- **Sink（汇点）**：
  - 重定向/绝对 URL：`HttpServletResponse.sendRedirect`, `RedirectView.setUrl`, `ResponseEntity.created/status`, `HttpHeaders.setLocation`, `UriComponentsBuilder.build`
  - 邮件：`JavaMailSender.send`, `javax.mail.Transport.send`
  - 框架特定：Struts2 `ServletRedirectResult.doExecute`

## 框架细化

### Servlet / Spring MVC & WebFlux
- 源：Servlet `getHeader("Host")/getServerName/...`；`ServletUriComponentsBuilder.fromCurrentRequest*`
- 汇：`sendRedirect`、`RedirectView.setUrl`、`ResponseEntity.created/status`、`HttpHeaders.setLocation`

### Struts2
- 源：`UrlHelper.buildUrl`（内部组合 scheme/host/port/path）
- 汇：`ServletRedirectResult.doExecute`、JSP 标签生成绝对 URL（间接命中）

### Play (Scala/Java)
- 源：`RequestHeader.host`、`Call.absoluteURL(request)`
- 汇：`Results.Redirect(...)` 等跳转

### JSF
- 源：依赖 `HttpServletRequest` 的 URL 构造
- 汇：`ExternalContext.redirect(url)`、`<h:link>` 绝对链接

## 结果格式

问题模式（problem）：定位在汇点表达式，消息内含 `source → sink`，便于快速定位与还原完整流。

## 注意

Java DB 需基于 Maven/Gradle 构建的项目创建。示例数据库路径为 `java-db/javaexample-db`。