<?php

namespace HnpLab\PhpHnpAnalyzer\Models;

/**
 * 污点汇模型类
 * 定义可能被恶意主机名污染的输出点
 */
class TaintSink
{
    private $name;
    private $description;
    private $impact;

    public function __construct(string $name, string $description, string $impact = 'high')
    {
        $this->name = $name;
        $this->description = $description;
        $this->impact = $impact;
    }

    public function getName(): string
    {
        return $this->name;
    }

    public function getDescription(): string
    {
        return $this->description;
    }

    public function getImpact(): string
    {
        return $this->impact;
    }

    /**
     * 获取预定义的污点汇列表
     */
    public static function getDefaultSinks(): array
    {
        return [
            new self(
                'header()',
                'HTTP header output function',
                'high'
            ),
            new self(
                'setcookie()',
                'Cookie setting function',
                'high'
            ),
            new self(
                'Location: redirect',
                'HTTP redirect header',
                'critical'
            ),
            new self(
                'Set-Cookie: header',
                'Cookie setting via header',
                'high'
            ),
            new self(
                'URL construction',
                'URL building with hostname',
                'medium'
            ),
            new self(
                'CSP header',
                'Content Security Policy header',
                'medium'
            ),
            new self(
                'CORS header',
                'Cross-Origin Resource Sharing header',
                'medium'
            ),
            new self(
                'HSTS header',
                'HTTP Strict Transport Security header',
                'low'
            )
        ];
    }
}
