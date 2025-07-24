# HNPATTACKER_WB

## 目录结构

```
HNPATTACKER_WB/
├── data/                  # 存放待扫描的 Python Web 项目
│   ├── flaskSaaS-master/
│   ├── JobCenter-master/
│   └── ...
├── queries/
│   └── hnp_detector.ql    # CodeQL 查询文件
├── results/
│   └── hnp-report-*.txt   # 扫描结果输出
├── auto_scan.py           # 自动化扫描脚本
```

## 依赖
- Python 3.6+
- CodeQL CLI (https://codeql.github.com/)

## 用法
1. 安装 CodeQL CLI 并确保 codeql 命令可用。
2. 将待检测的 Python Web 项目放入 data/ 目录下。
3. 运行自动扫描：
   ```
   python auto_scan.py
   ```
4. 扫描结果将输出到 results/hnp-report-[项目名].txt

## 查询说明
- queries/hnp_detector.ql 会检测 Host Name Pollution (HNP) 漏洞，追踪 Host 头部的 taint 流向敏感 sink，并检测是否有净化。
- 结果包含 taint 路径、文件名、行号、是否净化等信息。

## 示例输出
详见 results/hnp-report-EXAMPLE.txt 