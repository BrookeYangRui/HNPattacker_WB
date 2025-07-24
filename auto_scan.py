import os
import subprocess
import sys
import glob

DATA_DIR = os.path.join(os.path.dirname(__file__), 'data')
QUERY_FILE = os.path.join(os.path.dirname(__file__), 'queries', 'hnp_detector.ql')
RESULTS_DIR = os.path.join(os.path.dirname(__file__), 'results')

CODEQL_DB_DIR = os.path.join(os.path.dirname(__file__), 'codeql-dbs')
if not os.path.exists(CODEQL_DB_DIR):
    os.makedirs(CODEQL_DB_DIR)
if not os.path.exists(RESULTS_DIR):
    os.makedirs(RESULTS_DIR)

def is_python_project(path):
    # 判断是否为 Python 项目
    for marker in ['requirements.txt', 'setup.py', 'pyproject.toml']:
        if os.path.exists(os.path.join(path, marker)):
            return True
    py_files = glob.glob(os.path.join(path, '**', '*.py'), recursive=True)
    return len(py_files) > 0

def run_cmd(cmd, cwd=None):
    print(f"[CMD] {' '.join(cmd)}")
    try:
        result = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] Command failed: {' '.join(cmd)}\n{e.stderr}")
        return None

def main():
    for project in os.listdir(DATA_DIR):
        project_path = os.path.join(DATA_DIR, project)
        if not os.path.isdir(project_path):
            continue
        if not is_python_project(project_path):
            print(f"[SKIP] {project} 不是 Python 项目")
            continue
        print(f"[SCAN] 正在分析 {project} ...")
        db_path = os.path.join(CODEQL_DB_DIR, f"{project}-db")
        # 创建 CodeQL 数据库
        if os.path.exists(db_path):
            print(f"[INFO] 数据库已存在，跳过创建: {db_path}")
        else:
            cmd_create = ["codeql", "database", "create", db_path, "--language=python", "--source-root", project_path]
            if run_cmd(cmd_create) is None:
                print(f"[FAIL] 创建数据库失败: {project}")
                continue
        # 运行查询
        bqrs_path = os.path.join(CODEQL_DB_DIR, f"{project}-hnp.bqrs")
        cmd_query = ["codeql", "query", "run", QUERY_FILE, "--database", db_path, "--output", bqrs_path]
        if run_cmd(cmd_query) is None:
            print(f"[FAIL] 查询失败: {project}")
            continue
        # 解码 BQRS
        txt_path = os.path.join(RESULTS_DIR, f"hnp-report-{project}.txt")
        cmd_decode = ["codeql", "bqrs", "decode", bqrs_path, "--format=text", "--output", txt_path]
        if run_cmd(cmd_decode) is None:
            print(f"[FAIL] 解码 BQRS 失败: {project}")
            continue
        print(f"[OK] 结果已保存到 {txt_path}")

if __name__ == "__main__":
    main() 