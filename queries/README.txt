hnp_detector.ql
----------------

用途：
  检测 Python Web 项目中的 Host Name Pollution (HNP) 漏洞。
  标记 Host 头访问为 taint source，跟踪到敏感 sink，检测是否有主机名白名单、正则、startswith、validate_host 等净化逻辑。

用法：
  1. 使用 CodeQL 创建数据库：
     codeql database create <db-dir> --language=python --source-root <project-dir>
  2. 运行查询：
     codeql query run queries/hnp_detector.ql --database <db-dir> --output <output>.bqrs
  3. 解码结果：
     codeql bqrs decode <output>.bqrs --format=text --output <output>.txt

输出：
  - 文件名、行号、taint 路径、是否净化 