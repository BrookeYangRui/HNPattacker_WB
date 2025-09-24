# PHP Host Name Pollution 静态分析工具

这是一个专门用于检测 PHP 代码中 Host Name Pollution (HNP) 漏洞的静态分析工具。该工具基于 AST 解析和污点跟踪技术，能够识别从污点源到污点汇的数据流。

## 功能特性

- **污点源检测**: 识别 `$_SERVER['HTTP_HOST']`、`getenv('HTTP_HOST')` 等可能被攻击者控制的数据源
- **污点汇检测**: 检测 `header()`、`setcookie()`、URL 构建等可能被污染的输出点
- **数据流分析**: 跟踪污点数据在代码中的传播路径
- **多格式报告**: 支持 JSON、HTML、CSV、文本格式的漏洞报告
- **命令行工具**: 提供易于使用的命令行界面

## 安装

1. 克隆项目：
```bash
git clone <repository-url>
cd php-hnp-analyzer
```

2. 安装依赖：
```bash
composer install
```

## 使用方法

### 命令行工具

分析单个文件：
```bash
php bin/analyzer.php analyze examples/vulnerable_examples.php
```

分析整个目录：
```bash
php bin/analyzer.php analyze /path/to/php/project --recursive
```

生成 JSON 报告：
```bash
php bin/analyzer.php analyze file.php --format=json --output=report.json
```

生成 HTML 报告：
```bash
php bin/analyzer.php analyze file.php --format=html --output=report.html
```

### 编程接口

```php
<?php
use HnpLab\PhpHnpAnalyzer\Analyzer;

$analyzer = new Analyzer();

// 分析代码字符串
$vulnerabilities = $analyzer->analyzeCode($phpCode, 'file.php');

// 分析文件
$vulnerabilities = $analyzer->analyzeFile('path/to/file.php');

// 分析目录
$vulnerabilities = $analyzer->analyzeDirectory('path/to/directory');

// 生成报告
$report = $analyzer->generateReport('json');
```

## 检测的漏洞类型

### 污点源 (Sources)
- `$_SERVER['HTTP_HOST']` - HTTP Host 头
- `$_SERVER['SERVER_NAME']` - 服务器名称
- `$_SERVER['HTTP_X_FORWARDED_HOST']` - X-Forwarded-Host 头
- `getenv('HTTP_HOST')` - 环境变量中的主机名

### 污点汇 (Sinks)
- `header()` 函数调用
- `setcookie()` 函数调用
- 包含 `Location:` 的字符串
- 包含 `Set-Cookie:` 的字符串
- URL 构建和字符串拼接

## 示例

### 漏洞代码示例

```php
<?php
// 直接使用未验证的主机名进行重定向
function vulnerableRedirect() {
    $host = $_SERVER['HTTP_HOST'];
    header("Location: https://" . $host . "/dashboard");
}

// 设置 Cookie 时使用未验证的域名
function vulnerableCookie() {
    $domain = $_SERVER['HTTP_HOST'];
    setcookie('session', 'value', time() + 3600, '/', $domain);
}
```

### 安全代码示例

```php
<?php
// 使用白名单验证主机名
function safeRedirect() {
    $allowedHosts = ['example.com', 'www.example.com'];
    $host = $_SERVER['HTTP_HOST'];
    
    if (in_array($host, $allowedHosts)) {
        header("Location: https://" . $host . "/dashboard");
    } else {
        header("Location: https://example.com/error");
    }
}
```

## 报告格式

### JSON 格式
```json
{
    "summary": {
        "total": 5,
        "high": 3,
        "medium": 2,
        "low": 0,
        "critical": 0
    },
    "vulnerabilities": [
        {
            "file_path": "example.php",
            "line": 10,
            "type": "direct",
            "description": "Host Name Pollution vulnerability in header() function call",
            "severity": "high",
            "timestamp": "2024-01-01 12:00:00"
        }
    ]
}
```

### HTML 格式
生成包含样式和详细信息的 HTML 报告，适合在浏览器中查看。

### CSV 格式
生成逗号分隔的值文件，适合导入到电子表格软件中进行分析。

## 测试

运行测试套件：
```bash
composer test
```

或者使用 PHPUnit：
```bash
./vendor/bin/phpunit
```

## 限制和注意事项

1. **动态特性**: PHP 的动态特性（如 `eval()`、动态 `include`、变量变量）可能无法完全分析
2. **控制流分析**: 当前版本的控制流分析相对简单，可能产生误报
3. **框架支持**: 对特定 PHP 框架的深度支持需要额外开发
4. **性能**: 大型项目的分析可能需要较长时间

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个工具。

## 许可证

MIT License

## 相关研究

这个工具是 Host Name Pollution 研究项目的一部分，旨在帮助开发者和安全研究人员识别和修复 HNP 漏洞。

更多信息请访问：[HNP Lab](https://github.com/hnplab)
