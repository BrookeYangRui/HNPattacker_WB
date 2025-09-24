<?php

namespace HnpLab\PhpHnpAnalyzer\Models;

/**
 * 污点源模型类
 * 定义可能包含恶意主机名的数据源
 */
class TaintSource
{
    private $name;
    private $description;
    private $riskLevel;

    public function __construct(string $name, string $description, string $riskLevel = 'high')
    {
        $this->name = $name;
        $this->description = $description;
        $this->riskLevel = $riskLevel;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getDescription(): string
    {
        return $this->description;
    }

    public function getRiskLevel(): string
    {
        return $this->riskLevel;
    }

    /**
     * 获取预定义的污点源列表
     */
    public static function getDefaultSources(): array
    {
        return [
            new self(
                '$_SERVER[\'HTTP_HOST\']',
                'HTTP Host header from client request',
                'high'
            ),
            new self(
                '$_SERVER[\'SERVER_NAME\']',
                'Server name from server configuration',
                'medium'
            ),
            new self(
                '$_SERVER[\'HTTP_X_FORWARDED_HOST\']',
                'X-Forwarded-Host header (can be spoofed)',
                'high'
            ),
            new self(
                'getenv(\'HTTP_HOST\')',
                'HTTP Host from environment variables',
                'high'
            ),
            new self(
                '$_SERVER[\'HTTP_X_ORIGINAL_HOST\']',
                'X-Original-Host header',
                'high'
            ),
            new self(
                '$_SERVER[\'HTTP_X_FORWARDED_SERVER\']',
                'X-Forwarded-Server header',
                'medium'
            )
        ];
    }
}
