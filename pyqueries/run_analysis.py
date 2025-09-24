#!/usr/bin/env python3
"""
Complete HNP Analysis Runner
Runs CodeQL query and provides meaningful classification
"""

import subprocess
import json
import sys
from pathlib import Path

def run_codeql_analysis():
    """Compile & run query to local BQRS (query run), not database analyze"""
    print("🔍 Running CodeQL HNP analysis...")

    cmd = [
        "C:\\Users\\brook\\code\\codeql\\codeql.exe",
        "query", "run",
        "-d", "..\\py-db\\pyexample-db",
        "-o", "out.bqrs",
        "hnp_comprehensive.ql",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ CodeQL analysis failed: {result.stderr}")
        return None

    print("✅ CodeQL analysis completed")
    return True

def get_bqrs_results():
    """Get BQRS results in text format from local out.bqrs"""
    print("📊 Extracting BQRS results...")

    cmd = [
        "C:\\Users\\brook\\code\\codeql\\codeql.exe",
        "bqrs", "decode",
        "out.bqrs",
        "--format=text",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ BQRS decode failed: {result.stderr}")
        return None

    return result.stdout

def analyze_results(bqrs_output):
    """Analyze results and provide meaningful classification"""
    print("🔬 Analyzing results...")
    
    lines = bqrs_output.strip().split('\n')
    flows = []
    
    # Parse BQRS output
    in_data_section = False
    for line in lines:
        if '|' in line and 'source' in line.lower() and 'col1' in line.lower():
            in_data_section = True
            continue
        elif in_data_section and '|' in line and line.strip():
            if '+' in line or '-' in line:
                continue
            flows.append(line)
        elif in_data_section and not line.strip():
            break
    
    print(f"📈 Found {len(flows)} data flows")
    
    # Analyze flows
    analysis = {
        'total_flows': len(flows),
        'framework_distribution': {},
        'vulnerability_scenarios': {},
        'detailed_findings': []
    }
    
    for i, flow in enumerate(flows):
        # Extract information from flow
        parts = flow.split('|')
        if len(parts) >= 4:
            source = parts[0].strip()
            sink = parts[2].strip()
            
            # Classify based on sink content
            vuln_type, framework = classify_flow(source, sink)
            
            # Update statistics
            analysis['framework_distribution'][framework] = analysis['framework_distribution'].get(framework, 0) + 1
            analysis['vulnerability_scenarios'][vuln_type] = analysis['vulnerability_scenarios'].get(vuln_type, 0) + 1
            
            # Store detailed finding
            finding = {
                'id': i + 1,
                'source': source,
                'sink': sink,
                'vulnerability_scenario': vuln_type,
                'framework': framework,
                'description': f"HNP: {vuln_type} in {framework}"
            }
            analysis['detailed_findings'].append(finding)
    
    return analysis

def classify_flow(source, sink):
    """Classify a flow based on source and sink - focus on vulnerability scenarios"""
    source_lower = source.lower()
    sink_lower = sink.lower()
    
    # Framework detection
    framework = "Unknown"
    if 'django' in source_lower or 'django' in sink_lower:
        framework = "Django"
    elif 'flask' in source_lower or 'flask' in sink_lower:
        framework = "Flask"
    elif 'fastapi' in source_lower or 'fastapi' in sink_lower:
        framework = "FastAPI"
    elif 'tornado' in source_lower or 'tornado' in sink_lower:
        framework = "Tornado"
    elif 'pyramid' in source_lower or 'pyramid' in sink_lower:
        framework = "Pyramid"
    
    # Vulnerability scenario classification (no risk rating)
    if 'send_mail' in sink_lower or 'email' in sink_lower:
        return "Password Reset Attack", framework
    elif 'redirect' in sink_lower:
        return "Open Redirect", framework
    elif 'render_template' in sink_lower or 'template' in sink_lower:
        return "Template Injection", framework
    elif 'url_for' in sink_lower or 'reverse' in sink_lower:
        return "URL Generation Attack", framework
    elif 'attribute' in sink_lower:
        return "Attribute Manipulation", framework
    elif 'form' in sink_lower:
        return "Form Data Manipulation", framework
    elif 'request' in sink_lower:
        return "Request Parameter Pollution", framework
    elif 'dict' in sink_lower:
        return "Data Structure Pollution", framework
    elif 'async' in sink_lower or 'await' in sink_lower:
        return "Async Context Pollution", framework
    else:
        return "Unknown HNP Vulnerability", framework

def print_results(analysis):
    """Print formatted results - focus on vulnerability scenarios"""
    print("\n" + "="*80)
    print("🎯 HNP VULNERABILITY SCENARIO ANALYSIS")
    print("="*80)
    
    print(f"\n📊 SUMMARY:")
    print(f"Total HNP Flows Found: {analysis['total_flows']}")
    
    print(f"\n🏗️ FRAMEWORK DISTRIBUTION:")
    for framework, count in analysis['framework_distribution'].items():
        print(f"  📦 {framework}: {count}")
    
    print(f"\n💥 VULNERABILITY SCENARIOS:")
    for scenario, count in analysis['vulnerability_scenarios'].items():
        print(f"  ⚡ {scenario}: {count}")
    
    print(f"\n🔍 DETAILED SCENARIOS:")
    print("-" * 80)
    
    # Group by vulnerability scenario
    by_scenario = {}
    for finding in analysis['detailed_findings']:
        scenario = finding['vulnerability_scenario']
        if scenario not in by_scenario:
            by_scenario[scenario] = []
        by_scenario[scenario].append(finding)
    
    for scenario in sorted(by_scenario.keys()):
        findings = by_scenario[scenario]
        print(f"\n🔍 {scenario.upper()} SCENARIOS ({len(findings)} found):")
        for finding in findings[:3]:  # Show first 3 of each type
            print(f"  {finding['id']}. {finding['description']}")
            print(f"     Source: {finding['source'][:60]}...")
            print(f"     Sink: {finding['sink'][:60]}...")
        if len(findings) > 3:
            print(f"     ... and {len(findings) - 3} more similar scenarios")

def save_results(analysis):
    """Save results to JSON file"""
    with open('hnp_complete_analysis.json', 'w', encoding='utf-8') as f:
        json.dump(analysis, f, indent=2, ensure_ascii=False)
    print(f"\n💾 Results saved to: hnp_complete_analysis.json")

def main():
    """Main function"""
    print("🚀 Starting Complete HNP Analysis")
    print("="*50)
    
    # Step 1: Run CodeQL analysis
    if not run_codeql_analysis():
        sys.exit(1)
    
    # Step 2: Get BQRS results
    bqrs_output = get_bqrs_results()
    if not bqrs_output:
        sys.exit(1)
    
    # Step 3: Analyze results
    analysis = analyze_results(bqrs_output)
    
    # Step 4: Print results
    print_results(analysis)
    
    # Step 5: Save results
    save_results(analysis)
    
    print(f"\n✅ Analysis complete! Found {analysis['total_flows']} HNP vulnerability scenarios")

if __name__ == "__main__":
    main()
