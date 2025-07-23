import os
import subprocess

# 配置
CODEQL_PATH = "codeql"  # 如果codeql命令不是全局的，请写绝对路径
QUERY_FILE = "hnp_vulnerability_detector_ultimate.ql"
DATA_DIR = "data"
OUTPUT_DIR = "codeql_results"

os.makedirs(OUTPUT_DIR, exist_ok=True)

def run_cmd(cmd, cwd=None):
    print(f"运行命令: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"命令失败: {' '.join(cmd)}")
        print(result.stderr)
    else:
        print(result.stdout)
    return result.returncode == 0

for project in os.listdir(DATA_DIR):
    project_path = os.path.join(DATA_DIR, project)
    if not os.path.isdir(project_path):
        continue
    db_dir = os.path.join(OUTPUT_DIR, f"{project}_db")
    result_csv = os.path.join(OUTPUT_DIR, f"{project}_hnp_results.csv")
    print(f"\n==== 分析项目: {project} ====")
    # 1. 创建数据库
    if not run_cmd([CODEQL_PATH, "database", "create", db_dir, "--language=python", "--source-root", project_path]):
        print(f"数据库创建失败，跳过 {project}")
        continue
    # 2. 运行分析
    if not run_cmd([CODEQL_PATH, "database", "analyze", db_dir, QUERY_FILE, "--format=csv", f"--output={result_csv}"]):
        print(f"分析失败，跳过 {project}")
        continue
    print(f"分析完成，结果保存在: {result_csv}")

print("\n全部分析完成！") 