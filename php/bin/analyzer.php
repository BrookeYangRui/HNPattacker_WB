<?php

require_once __DIR__ . '/../vendor/autoload.php';

use HnpLab\PhpHnpAnalyzer\Analyzer;
use Symfony\Component\Console\Application;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Input\InputOption;
use Symfony\Component\Console\Output\OutputInterface;

class AnalyzeCommand extends Command
{
    protected static $defaultName = 'analyze';

    protected function configure()
    {
        $this
            ->setDescription('分析 PHP 代码中的 Host Name Pollution 漏洞')
            ->addArgument('target', InputArgument::REQUIRED, '要分析的文件或目录路径')
            ->addOption('format', 'f', InputOption::VALUE_OPTIONAL, '输出格式 (json, html, csv, text)', 'text')
            ->addOption('output', 'o', InputOption::VALUE_OPTIONAL, '输出文件路径')
            ->addOption('recursive', 'r', InputOption::VALUE_NONE, '递归分析目录')
            ->setHelp('
这个工具可以检测 PHP 代码中的 Host Name Pollution (HNP) 漏洞。

示例用法:
  php bin/analyzer.php analyze file.php
  php bin/analyzer.php analyze /path/to/directory --recursive
  php bin/analyzer.php analyze file.php --format=json --output=report.json
            ');
    }

    protected function execute(InputInterface $input, OutputInterface $output)
    {
        $target = $input->getArgument('target');
        $format = $input->getOption('format');
        $outputFile = $input->getOption('output');
        $recursive = $input->getOption('recursive');

        if (!file_exists($target)) {
            $output->writeln('<error>错误: 目标路径不存在: ' . $target . '</error>');
            return Command::FAILURE;
        }

        $analyzer = new Analyzer();
        $vulnerabilities = [];

        try {
            if (is_file($target)) {
                $output->writeln('<info>分析文件: ' . $target . '</info>');
                $vulnerabilities = $analyzer->analyzeFile($target);
            } elseif (is_dir($target)) {
                $output->writeln('<info>分析目录: ' . $target . '</info>');
                $vulnerabilities = $analyzer->analyzeDirectory($target);
            } else {
                $output->writeln('<error>错误: 无效的目标路径</error>');
                return Command::FAILURE;
            }

            $output->writeln('<info>发现 ' . count($vulnerabilities) . ' 个漏洞</info>');

            // 生成报告
            $report = $analyzer->generateReport($format);

            if ($outputFile) {
                file_put_contents($outputFile, $report);
                $output->writeln('<info>报告已保存到: ' . $outputFile . '</info>');
            } else {
                $output->write($report);
            }

            return Command::SUCCESS;

        } catch (\Exception $e) {
            $output->writeln('<error>分析过程中出错: ' . $e->getMessage() . '</error>');
            return Command::FAILURE;
        }
    }
}

// 创建控制台应用
$application = new Application('PHP HNP Analyzer', '1.0.0');
$application->add(new AnalyzeCommand());
$application->run();
