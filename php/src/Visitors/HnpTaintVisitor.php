<?php

namespace HnpLab\PhpHnpAnalyzer\Visitors;

use PhpParser\Node;
use PhpParser\NodeVisitorAbstract;
use PhpParser\Node\Expr\Variable;
use PhpParser\Node\Expr\ArrayDimFetch;
use PhpParser\Node\Expr\FuncCall;
use PhpParser\Node\Expr\MethodCall;
use PhpParser\Node\Expr\StaticCall;
use PhpParser\Node\Expr\BinaryOp\Concat;
use PhpParser\Node\Scalar\String_;
use HnpLab\PhpHnpAnalyzer\Models\Vulnerability;
use HnpLab\PhpHnpAnalyzer\Models\TaintSource;
use HnpLab\PhpHnpAnalyzer\Models\TaintSink;

/**
 * HNP 污点跟踪访问器
 * 检测从 source 到 sink 的数据流
 */
class HnpTaintVisitor extends NodeVisitorAbstract
{
    private $filePath;
    private $vulnerabilities = [];
    private $taintedVariables = [];
    private $currentScope = [];

    public function __construct(string $filePath)
    {
        $this->filePath = $filePath;
    }

    public function enterNode(Node $node)
    {
        // 检测污点源 (Source)
        if ($this->isTaintSource($node)) {
            $this->markAsTainted($node);
        }

        // 检测污点汇 (Sink)
        if ($this->isTaintSink($node)) {
            $this->checkTaintFlow($node);
        }

        // 处理变量赋值
        if ($node instanceof Node\Expr\Assign) {
            $this->handleAssignment($node);
        }

        // 处理函数调用中的参数传递
        if ($node instanceof FuncCall || $node instanceof MethodCall || $node instanceof StaticCall) {
            $this->handleFunctionCall($node);
        }

        // 处理字符串拼接
        if ($node instanceof Concat) {
            $this->handleStringConcatenation($node);
        }
    }

    /**
     * 检测是否为污点源
     */
    private function isTaintSource(Node $node): bool
    {
        // $_SERVER['HTTP_HOST']
        if ($node instanceof ArrayDimFetch) {
            if ($node->var instanceof Variable && $node->var->name === '_SERVER') {
                if ($node->dim instanceof String_ && $node->dim->value === 'HTTP_HOST') {
                    return true;
                }
            }
        }

        // getenv('HTTP_HOST')
        if ($node instanceof FuncCall) {
            if ($node->name instanceof Node\Name && $node->name->toString() === 'getenv') {
                if (count($node->args) > 0) {
                    $arg = $node->args[0]->value;
                    if ($arg instanceof String_ && $arg->value === 'HTTP_HOST') {
                        return true;
                    }
                }
            }
        }

        // $_SERVER['SERVER_NAME']
        if ($node instanceof ArrayDimFetch) {
            if ($node->var instanceof Variable && $node->var->name === '_SERVER') {
                if ($node->dim instanceof String_ && $node->dim->value === 'SERVER_NAME') {
                    return true;
                }
            }
        }

        // $_SERVER['HTTP_X_FORWARDED_HOST']
        if ($node instanceof ArrayDimFetch) {
            if ($node->var instanceof Variable && $node->var->name === '_SERVER') {
                if ($node->dim instanceof String_ && $node->dim->value === 'HTTP_X_FORWARDED_HOST') {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * 检测是否为污点汇
     */
    private function isTaintSink(Node $node): bool
    {
        // header() 函数调用
        if ($node instanceof FuncCall) {
            if ($node->name instanceof Node\Name && $node->name->toString() === 'header') {
                return true;
            }
        }

        // setcookie() 函数调用
        if ($node instanceof FuncCall) {
            if ($node->name instanceof Node\Name && $node->name->toString() === 'setcookie') {
                return true;
            }
        }

        // 字符串中包含 Location: 或 Set-Cookie:
        if ($node instanceof String_) {
            $value = strtolower($node->value);
            if (strpos($value, 'location:') === 0 || strpos($value, 'set-cookie:') === 0) {
                return true;
            }
        }

        // 字符串拼接中包含 http:// 或 https://
        if ($node instanceof Concat) {
            return $this->containsUrlPattern($node);
        }

        return false;
    }

    /**
     * 检查字符串拼接是否包含 URL 模式
     */
    private function containsUrlPattern(Concat $node): bool
    {
        $left = $this->extractStringValue($node->left);
        $right = $this->extractStringValue($node->right);
        
        $combined = $left . $right;
        return strpos($combined, 'http://') !== false || strpos($combined, 'https://') !== false;
    }

    /**
     * 从节点中提取字符串值
     */
    private function extractStringValue(Node $node): string
    {
        if ($node instanceof String_) {
            return $node->value;
        }
        if ($node instanceof Variable) {
            return '$' . $node->name;
        }
        if ($node instanceof ArrayDimFetch) {
            return '$_SERVER[...]';
        }
        return '';
    }

    /**
     * 标记节点为污点源
     */
    private function markAsTainted(Node $node): void
    {
        $taintId = $this->generateTaintId($node);
        $this->taintedVariables[$taintId] = [
            'node' => $node,
            'line' => $node->getLine(),
            'type' => 'source'
        ];
    }

    /**
     * 检查污点流
     */
    private function checkTaintFlow(Node $node): void
    {
        // 检查直接污点流
        if ($this->isDirectlyTainted($node)) {
            $this->createVulnerability($node, 'direct');
        }

        // 检查间接污点流（通过变量）
        if ($this->isIndirectlyTainted($node)) {
            $this->createVulnerability($node, 'indirect');
        }
    }

    /**
     * 检查是否直接污点
     */
    private function isDirectlyTainted(Node $node): bool
    {
        if ($node instanceof FuncCall && $node->name instanceof Node\Name) {
            foreach ($node->args as $arg) {
                if ($this->isTaintSource($arg->value)) {
                    return true;
                }
            }
        }

        if ($node instanceof Concat) {
            return $this->isTaintSource($node->left) || $this->isTaintSource($node->right);
        }

        return false;
    }

    /**
     * 检查是否间接污点
     */
    private function isIndirectlyTainted(Node $node): bool
    {
        if ($node instanceof FuncCall && $node->name instanceof Node\Name) {
            foreach ($node->args as $arg) {
                if ($this->isVariableTainted($arg->value)) {
                    return true;
                }
            }
        }

        if ($node instanceof Concat) {
            return $this->isVariableTainted($node->left) || $this->isVariableTainted($node->right);
        }

        return false;
    }

    /**
     * 检查变量是否被污点
     */
    private function isVariableTainted(Node $node): bool
    {
        if ($node instanceof Variable) {
            $varName = '$' . $node->name;
            return isset($this->taintedVariables[$varName]);
        }

        if ($node instanceof ArrayDimFetch) {
            $arrayName = '$' . $node->var->name;
            return isset($this->taintedVariables[$arrayName]);
        }

        return false;
    }

    /**
     * 处理变量赋值
     */
    private function handleAssignment(Node\Expr\Assign $node): void
    {
        if ($node->var instanceof Variable) {
            $varName = '$' . $node->var->name;
            
            // 如果右侧是污点源，标记左侧变量为污点
            if ($this->isTaintSource($node->expr)) {
                $this->taintedVariables[$varName] = [
                    'node' => $node->var,
                    'line' => $node->getLine(),
                    'type' => 'tainted_variable'
                ];
            }
            
            // 如果右侧是污点变量，传播污点
            if ($this->isVariableTainted($node->expr)) {
                $this->taintedVariables[$varName] = [
                    'node' => $node->var,
                    'line' => $node->getLine(),
                    'type' => 'tainted_variable'
                ];
            }
        }
    }

    /**
     * 处理函数调用
     */
    private function handleFunctionCall(Node $node): void
    {
        // 这里可以添加更复杂的函数调用分析
        // 比如检测框架特定的方法调用
    }

    /**
     * 处理字符串拼接
     */
    private function handleStringConcatenation(Concat $node): void
    {
        // 如果拼接中包含污点变量，标记整个拼接为污点
        if ($this->isVariableTainted($node->left) || $this->isVariableTainted($node->right)) {
            $concatId = $this->generateTaintId($node);
            $this->taintedVariables[$concatId] = [
                'node' => $node,
                'line' => $node->getLine(),
                'type' => 'tainted_concat'
            ];
        }
    }

    /**
     * 创建漏洞记录
     */
    private function createVulnerability(Node $node, string $type): void
    {
        $vulnerability = new Vulnerability(
            $this->filePath,
            $node->getLine(),
            $type,
            $this->getVulnerabilityDescription($node, $type)
        );

        $this->vulnerabilities[] = $vulnerability;
    }

    /**
     * 获取漏洞描述
     */
    private function getVulnerabilityDescription(Node $node, string $type): string
    {
        if ($node instanceof FuncCall) {
            $funcName = $node->name instanceof Node\Name ? $node->name->toString() : 'unknown';
            return "Host Name Pollution vulnerability in {$funcName}() function call";
        }

        if ($node instanceof Concat) {
            return "Host Name Pollution vulnerability in string concatenation";
        }

        return "Host Name Pollution vulnerability detected";
    }

    /**
     * 生成污点 ID
     */
    private function generateTaintId(Node $node): string
    {
        return spl_object_hash($node);
    }

    /**
     * 获取发现的漏洞
     */
    public function getVulnerabilities(): array
    {
        return $this->vulnerabilities;
    }
}
