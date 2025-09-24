<?php

/**
 * 安全的代码示例
 * 这些代码展示了如何正确验证和清理主机名
 */

// 安全示例 1: 使用白名单验证主机名
function safeRedirect1() {
    $allowedHosts = ['example.com', 'www.example.com', 'api.example.com'];
    $host = $_SERVER['HTTP_HOST'];
    
    if (in_array($host, $allowedHosts)) {
        header("Location: https://" . $host . "/dashboard");
    } else {
        header("Location: https://example.com/error");
    }
}

// 安全示例 2: 使用正则表达式验证主机名
function safeRedirect2() {
    $host = $_SERVER['HTTP_HOST'];
    
    if (preg_match('/^[a-zA-Z0-9.-]+\.example\.com$/', $host)) {
        header("Location: https://" . $host . "/login");
    } else {
        header("Location: https://example.com/");
    }
}

// 安全示例 3: 使用 filter_var 验证主机名
function safeRedirect3() {
    $host = $_SERVER['HTTP_HOST'];
    
    if (filter_var($host, FILTER_VALIDATE_DOMAIN, FILTER_FLAG_HOSTNAME)) {
        // 进一步验证是否为允许的域名
        $allowedDomain = 'example.com';
        if (strpos($host, $allowedDomain) !== false) {
            header("Location: https://" . $host . "/dashboard");
        }
    }
}

// 安全示例 4: 硬编码安全的主机名
function safeRedirect4() {
    $secureHost = 'example.com';
    header("Location: https://" . $secureHost . "/dashboard");
}

// 安全示例 5: 使用配置中的安全主机名
function safeRedirect5() {
    $config = [
        'allowed_hosts' => ['example.com', 'www.example.com'],
        'default_host' => 'example.com'
    ];
    
    $host = $_SERVER['HTTP_HOST'];
    
    if (in_array($host, $config['allowed_hosts'])) {
        $targetHost = $host;
    } else {
        $targetHost = $config['default_host'];
    }
    
    header("Location: https://" . $targetHost . "/dashboard");
}

// 安全示例 6: 使用 parse_url 验证 URL
function safeUrlConstruction() {
    $host = $_SERVER['HTTP_HOST'];
    $url = "https://" . $host . "/api/endpoint";
    
    $parsed = parse_url($url);
    if ($parsed && isset($parsed['host'])) {
        $validHosts = ['api.example.com', 'example.com'];
        if (in_array($parsed['host'], $validHosts)) {
            return $url;
        }
    }
    
    return "https://example.com/api/endpoint";
}

// 安全示例 7: 使用 CSP 头限制重定向
function safeRedirectWithCSP() {
    $host = $_SERVER['HTTP_HOST'];
    
    // 设置 CSP 头限制重定向目标
    header("Content-Security-Policy: frame-ancestors 'self' https://example.com");
    
    if (strpos($host, 'example.com') !== false) {
        header("Location: https://" . $host . "/dashboard");
    }
}

// 安全示例 8: 使用 HTTPS 和 HSTS
function safeRedirectWithHSTS() {
    $host = $_SERVER['HTTP_HOST'];
    
    // 强制 HTTPS
    if (!isset($_SERVER['HTTPS']) || $_SERVER['HTTPS'] !== 'on') {
        header("Location: https://" . $host . $_SERVER['REQUEST_URI']);
        exit;
    }
    
    // 设置 HSTS 头
    header("Strict-Transport-Security: max-age=31536000; includeSubDomains");
    
    if (in_array($host, ['example.com', 'www.example.com'])) {
        header("Location: https://" . $host . "/secure");
    }
}
