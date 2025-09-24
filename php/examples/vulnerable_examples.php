<?php

/**
 * 包含 Host Name Pollution 漏洞的示例代码
 * 这些代码展示了常见的 HNP 漏洞模式
 */

// 示例 1: 直接使用 $_SERVER['HTTP_HOST'] 进行重定向
function vulnerableRedirect1() {
    $host = $_SERVER['HTTP_HOST'];
    header("Location: https://" . $host . "/dashboard");
}

// 示例 2: 使用 getenv() 获取主机名
function vulnerableRedirect2() {
    $host = getenv('HTTP_HOST');
    header("Location: http://" . $host . "/login");
}

// 示例 3: 设置 Cookie 时使用未验证的主机名
function vulnerableCookie() {
    $domain = $_SERVER['HTTP_HOST'];
    setcookie('session', 'value', time() + 3600, '/', $domain);
}

// 示例 4: 字符串拼接构建 URL
function vulnerableUrlConstruction() {
    $host = $_SERVER['HTTP_HOST'];
    $url = "https://" . $host . "/api/endpoint";
    return $url;
}

// 示例 5: 使用 X-Forwarded-Host 头
function vulnerableForwardedHost() {
    $host = $_SERVER['HTTP_X_FORWARDED_HOST'];
    header("Location: https://" . $host . "/admin");
}

// 示例 6: 复杂的字符串拼接
function vulnerableComplexConcatenation() {
    $baseUrl = "https://" . $_SERVER['HTTP_HOST'];
    $path = "/user/profile";
    $fullUrl = $baseUrl . $path;
    header("Location: " . $fullUrl);
}

// 示例 7: 通过变量传递污点数据
function vulnerableVariablePassing() {
    $host = $_SERVER['HTTP_HOST'];
    $redirectUrl = buildRedirectUrl($host);
    header("Location: " . $redirectUrl);
}

function buildRedirectUrl($host) {
    return "https://" . $host . "/dashboard";
}

// 示例 8: 使用 SERVER_NAME
function vulnerableServerName() {
    $host = $_SERVER['SERVER_NAME'];
    setcookie('preference', 'value', time() + 86400, '/', $host);
}

// 示例 9: 条件判断中的污点传播
function vulnerableConditional() {
    $host = $_SERVER['HTTP_HOST'];
    if (strpos($host, 'admin') !== false) {
        header("Location: https://" . $host . "/admin-panel");
    }
}

// 示例 10: 数组访问中的污点传播
function vulnerableArrayAccess() {
    $serverVars = $_SERVER;
    $host = $serverVars['HTTP_HOST'];
    header("Location: https://" . $host . "/secure");
}
