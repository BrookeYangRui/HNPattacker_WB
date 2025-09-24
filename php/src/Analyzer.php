<?php

namespace HnpLab\PhpHnpAnalyzer;

use PhpParser\NodeTraverser;
use PhpParser\ParserFactory;
use PhpParser\NodeVisitor\NameResolver;
use HnpLab\PhpHnpAnalyzer\Visitors\HnpTaintVisitor;
use HnpLab\PhpHnpAnalyzer\Reporters\VulnerabilityReporter;

/**
 * PHP Host Name Pollution 静态分析器主类
 */
class Analyzer
{
    private $parser;
    private $reporter;
    private $vulnerabilities = [];

    public function __construct()
    {
        $this->parser = (new ParserFactory())->createForNewestSupportedVersion();
        $this->reporter = new VulnerabilityReporter();
    }

    /**
     * 分析单个 PHP 文件
     */
    public function analyzeFile(string $filePath): array
    {
        if (!file_exists($filePath)) {
            throw new \InvalidArgumentException("文件不存在: {$filePath}");
        }

        $code = file_get_contents($filePath);
        return $this->analyzeCode($code, $filePath);
    }

    /**
     * 分析 PHP 代码字符串
     */
    public function analyzeCode(string $code, string $filePath = 'unknown'): array
    {
        try {
            // 解析 PHP 代码为 AST
            $ast = $this->parser->parse($code);
            
            if ($ast === null) {
                return [];
            }

            // 创建遍历器
            $traverser = new NodeTraverser();
            
            // 添加名称解析器（处理命名空间和类名）
            $traverser->addVisitor(new NameResolver());
            
            // 添加 HNP 污点跟踪访问器
            $hnpVisitor = new HnpTaintVisitor($filePath);
            $traverser->addVisitor($hnpVisitor);
            
            // 遍历 AST
            $traverser->traverse($ast);
            
            // 获取发现的漏洞
            $vulnerabilities = $hnpVisitor->getVulnerabilities();
            
            // 存储到总漏洞列表
            $this->vulnerabilities = array_merge($this->vulnerabilities, $vulnerabilities);
            
            return $vulnerabilities;
            
        } catch (\Exception $e) {
            throw new \RuntimeException("分析文件 {$filePath} 时出错: " . $e->getMessage());
        }
    }

    /**
     * 分析目录中的所有 PHP 文件
     */
    public function analyzeDirectory(string $directory): array
    {
        $vulnerabilities = [];
        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($directory)
        );

        foreach ($iterator as $file) {
            if ($file->isFile() && $file->getExtension() === 'php') {
                try {
                    $fileVulns = $this->analyzeFile($file->getPathname());
                    $vulnerabilities = array_merge($vulnerabilities, $fileVulns);
                } catch (\Exception $e) {
                    echo "警告: 无法分析文件 {$file->getPathname()}: " . $e->getMessage() . "\n";
                }
            }
        }

        return $vulnerabilities;
    }

    /**
     * 获取所有发现的漏洞
     */
    public function getVulnerabilities(): array
    {
        return $this->vulnerabilities;
    }

    /**
     * 生成漏洞报告
     */
    public function generateReport(string $format = 'json'): string
    {
        return $this->reporter->generate($this->vulnerabilities, $format);
    }

    /**
     * 清空漏洞记录
     */
    public function clearVulnerabilities(): void
    {
        $this->vulnerabilities = [];
    }
}
