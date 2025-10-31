#!/usr/bin/env python3
"""
Tiercade AI Prompt Test Results Analyzer

Parses JSON test reports and generates detailed analysis and visualizations.
"""

import json
import sys
from pathlib import Path
from typing import Dict, List, Any
from datetime import datetime

def load_report(report_path: Path) -> Dict[str, Any]:
    """Load a test report JSON file."""
    with open(report_path) as f:
        return json.load(f)

def analyze_suite(suite_id: str, report: Dict[str, Any]) -> Dict[str, Any]:
    """Analyze a single test suite report."""
    total_runs = report.get('totalRuns', 0)
    successful_runs = report.get('successfulRuns', 0)
    failed_runs = report.get('failedRuns', 0)
    total_duration = report.get('totalDuration', 0)

    success_rate = (successful_runs / max(1, total_runs)) * 100
    avg_duration = total_duration / max(1, total_runs)

    # Analyze rankings
    rankings = report.get('rankings', {})
    top_prompts = {
        'byPassRate': rankings.get('byPassRate', [])[:3],
        'byQuality': rankings.get('byQuality', [])[:3],
        'bySpeed': rankings.get('bySpeed', [])[:3],
        'byConsistency': rankings.get('byConsistency', [])[:3]
    }

    # Analyze aggregate results
    aggregates = report.get('aggregateResults', [])
    prompt_analysis = []

    for agg in aggregates:
        stats = agg.get('overallStats', {})
        prompt_analysis.append({
            'promptId': agg.get('promptId'),
            'promptName': agg.get('promptName'),
            'passAtNRate': stats.get('passAtNRate', 0) * 100,
            'meanDupRate': stats.get('meanDupRate', 0) * 100,
            'stdevDupRate': stats.get('stdevDupRate', 0) * 100,
            'jsonStrictRate': stats.get('jsonStrictRate', 0) * 100,
            'insufficientRate': stats.get('insufficientRate', 0) * 100,
            'formatErrorRate': stats.get('formatErrorRate', 0) * 100,
            'meanQualityScore': stats.get('meanQualityScore', 0),
            'totalRuns': agg.get('totalRuns', 0)
        })

    # Sort by pass rate
    prompt_analysis.sort(key=lambda x: x['passAtNRate'], reverse=True)

    return {
        'suite_id': suite_id,
        'suite_name': report.get('suiteName', suite_id),
        'total_runs': total_runs,
        'successful_runs': successful_runs,
        'failed_runs': failed_runs,
        'success_rate': success_rate,
        'total_duration': total_duration,
        'avg_duration_per_run': avg_duration,
        'top_prompts': top_prompts,
        'prompt_analysis': prompt_analysis,
        'environment': report.get('environment', {})
    }

def generate_markdown_report(results_dir: Path, analyses: List[Dict[str, Any]]) -> str:
    """Generate a detailed markdown analysis report."""

    lines = [
        "# Detailed AI Prompt Test Analysis",
        "",
        f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        "",
        "---",
        "",
        "## Executive Summary",
        ""
    ]

    # Overall statistics
    total_tests = sum(a['total_runs'] for a in analyses)
    total_passed = sum(a['successful_runs'] for a in analyses)
    total_failed = sum(a['failed_runs'] for a in analyses)
    overall_rate = (total_passed / max(1, total_tests)) * 100
    total_time = sum(a['total_duration'] for a in analyses)

    lines.extend([
        f"- **Total Test Runs Across All Suites:** {total_tests:,}",
        f"- **Overall Success Rate:** {overall_rate:.1f}%",
        f"- **Total Test Duration:** {total_time:.1f}s ({total_time/60:.1f} minutes)",
        f"- **Average Time Per Test:** {total_time/max(1, total_tests):.2f}s",
        "",
        "### Suite Performance Comparison",
        "",
        "| Suite | Runs | Success Rate | Duration | Avg/Run |",
        "|-------|------|--------------|----------|---------|"
    ])

    for analysis in analyses:
        lines.append(
            f"| {analysis['suite_name']} | {analysis['total_runs']} | "
            f"{analysis['success_rate']:.1f}% | "
            f"{analysis['total_duration']:.1f}s | "
            f"{analysis['avg_duration_per_run']:.2f}s |"
        )

    lines.extend([
        "",
        "---",
        "",
        "## Detailed Suite Analysis",
        ""
    ])

    # Detailed analysis for each suite
    for analysis in analyses:
        lines.extend([
            f"### {analysis['suite_name']}",
            "",
            f"**Suite ID:** `{analysis['suite_id']}`",
            "",
            "#### Performance Metrics",
            "",
            f"- **Total Runs:** {analysis['total_runs']}",
            f"- **Successful:** {analysis['successful_runs']} ({analysis['success_rate']:.1f}%)",
            f"- **Failed:** {analysis['failed_runs']}",
            f"- **Total Duration:** {analysis['total_duration']:.1f}s",
            f"- **Average Duration/Run:** {analysis['avg_duration_per_run']:.2f}s",
            ""
        ])

        # Environment info
        env = analysis.get('environment', {})
        if env:
            lines.extend([
                "#### Test Environment",
                "",
                f"- **OS Version:** {env.get('osVersion', 'N/A')}",
                f"- **Top-P Sampling:** {'Available' if env.get('hasTopP') else 'Not Available'}",
                f"- **Build Date:** {env.get('buildDate', 'N/A')}",
                ""
            ])

        # Top performers
        top_prompts = analysis.get('top_prompts', {})

        if top_prompts.get('byPassRate'):
            lines.extend([
                "#### 🏆 Top Prompts by Pass Rate",
                ""
            ])
            for i, prompt in enumerate(top_prompts['byPassRate'], 1):
                lines.append(
                    f"{i}. **{prompt['promptName']}** - "
                    f"Score: {prompt['score']:.3f}"
                )
            lines.append("")

        if top_prompts.get('byQuality'):
            lines.extend([
                "#### ⭐ Top Prompts by Quality Score",
                ""
            ])
            for i, prompt in enumerate(top_prompts['byQuality'], 1):
                lines.append(
                    f"{i}. **{prompt['promptName']}** - "
                    f"Score: {prompt['score']:.3f}"
                )
            lines.append("")

        if top_prompts.get('bySpeed'):
            lines.extend([
                "#### ⚡ Top Prompts by Speed",
                ""
            ])
            for i, prompt in enumerate(top_prompts['bySpeed'], 1):
                lines.append(
                    f"{i}. **{prompt['promptName']}** - "
                    f"Score: {prompt['score']:.3f}"
                )
            lines.append("")

        # Detailed prompt analysis table
        if analysis['prompt_analysis']:
            lines.extend([
                "#### Detailed Prompt Analysis",
                "",
                "| Prompt | Pass@N | Dup Rate | JSON | Quality | Runs |",
                "|--------|--------|----------|------|---------|------|"
            ])

            for prompt in analysis['prompt_analysis'][:10]:  # Top 10
                lines.append(
                    f"| {prompt['promptName'][:30]} | "
                    f"{prompt['passAtNRate']:.1f}% | "
                    f"{prompt['meanDupRate']:.1f}±{prompt['stdevDupRate']:.1f}% | "
                    f"{prompt['jsonStrictRate']:.0f}% | "
                    f"{prompt['meanQualityScore']:.3f} | "
                    f"{prompt['totalRuns']} |"
                )

            lines.append("")

        lines.extend([
            "---",
            ""
        ])

    # Recommendations section
    lines.extend([
        "## Recommendations & Insights",
        "",
        "### Best Performing Prompts Overall",
        ""
    ])

    # Find best prompts across all suites
    all_prompts = {}
    for analysis in analyses:
        for prompt in analysis.get('prompt_analysis', []):
            pid = prompt['promptId']
            if pid not in all_prompts:
                all_prompts[pid] = {
                    'name': prompt['promptName'],
                    'total_runs': 0,
                    'total_pass_rate': 0,
                    'total_dup_rate': 0,
                    'suite_count': 0
                }
            all_prompts[pid]['total_runs'] += prompt['totalRuns']
            all_prompts[pid]['total_pass_rate'] += prompt['passAtNRate']
            all_prompts[pid]['total_dup_rate'] += prompt['meanDupRate']
            all_prompts[pid]['suite_count'] += 1

    # Calculate averages
    for pid, data in all_prompts.items():
        data['avg_pass_rate'] = data['total_pass_rate'] / data['suite_count']
        data['avg_dup_rate'] = data['total_dup_rate'] / data['suite_count']

    # Sort by average pass rate
    best_overall = sorted(
        all_prompts.items(),
        key=lambda x: x[1]['avg_pass_rate'],
        reverse=True
    )[:5]

    for i, (pid, data) in enumerate(best_overall, 1):
        lines.extend([
            f"{i}. **{data['name']}** (`{pid}`)",
            f"   - Average Pass Rate: {data['avg_pass_rate']:.1f}%",
            f"   - Average Dup Rate: {data['avg_dup_rate']:.1f}%",
            f"   - Tested in {data['suite_count']} suite(s)",
            f"   - Total Runs: {data['total_runs']}",
            ""
        ])

    lines.extend([
        "### Areas for Improvement",
        ""
    ])

    # Find worst performing prompts
    worst_overall = sorted(
        all_prompts.items(),
        key=lambda x: x[1]['avg_pass_rate']
    )[:3]

    for i, (pid, data) in enumerate(worst_overall, 1):
        lines.extend([
            f"{i}. **{data['name']}** (`{pid}`)",
            f"   - Average Pass Rate: {data['avg_pass_rate']:.1f}%",
            f"   - Consider revising or removing this prompt",
            ""
        ])

    return "\n".join(lines)

def main():
    if len(sys.argv) < 2:
        print("Usage: analyze_test_results.py <results_directory>")
        sys.exit(1)

    results_dir = Path(sys.argv[1])

    if not results_dir.exists():
        print(f"Error: Directory not found: {results_dir}")
        sys.exit(1)

    # Find all unified suite report JSON files
    report_files = sorted(results_dir.glob("*_report.json"))

    if not report_files:
        print(f"Error: No report files found in {results_dir}")
        sys.exit(1)

    print(f"Found {len(report_files)} unified test reports")
    print()

    # Analyze each unified report
    analyses = []
    for report_path in report_files:
        suite_id = report_path.stem.replace('_report', '')
        print(f"Analyzing {suite_id}...")

        try:
            report = load_report(report_path)
            analysis = analyze_suite(suite_id, report)
            analyses.append(analysis)
            print(f"  ✅ Success rate: {analysis['success_rate']:.1f}%")
        except Exception as e:
            print(f"  ❌ Error: {e}")

    print()
    print("Generating detailed analysis report...")

    # Generate markdown for unified reports
    markdown_report = generate_markdown_report(results_dir, analyses)

    # Also ingest coordinator experiment reports if present and append summary
    coord_files = list(results_dir.glob("coordinator_experiments*_report.json"))
    if not coord_files:
        # Some runs save coordinator report without _report suffix
        coord_files = [p for p in results_dir.glob("coordinator_experiments*.json") if p.name.endswith("report.json")]

    if coord_files:
        lines = ["\n---\n", "## Coordinator Experiments (Appendix)", "\n"]
        for path in coord_files:
            try:
                data = load_report(path)
                results = data.get('results', [])
                scenarios = data.get('scenarios', [])
                total_runs = data.get('totalRuns', len(results))
                success = data.get('successfulRuns', sum(1 for r in results if r.get('passAtN')))
                lines.extend([
                    f"### {path.name}",
                    "",
                    f"- **Scenarios:** {', '.join(scenarios) if scenarios else 'n/a'}",
                    f"- **Runs:** {total_runs}",
                    f"- **Successful:** {success}",
                    ""
                ])
                # Per-scenario quick stats
                by_scenario = {}
                for r in results:
                    sid = r.get('scenarioId', 'unknown')
                    by_scenario.setdefault(sid, []).append(r)
                lines.append("| Scenario | Runs | Pass | Avg Unique | Avg DupRate | Escalate |")
                lines.append("|---------|------|------|------------|-------------|----------|")
                for sid, runs in by_scenario.items():
                    name = runs[0].get('scenarioName', sid)
                    n = len(runs)
                    p = sum(1 for r in runs if r.get('passAtN'))
                    avg_u = sum(r.get('uniqueItems', 0) for r in runs) / max(1, n)
                    dup_vals = []
                    for r in runs:
                        diag = r.get('diagnostics') or {}
                        val = diag.get('dupRate')
                        if isinstance(val, (int, float)):
                            dup_vals.append(val)
                    avg_dup = (sum(dup_vals) / len(dup_vals)) if dup_vals else 0.0
                    esc = sum(1 for r in runs if r.get('wouldEscalatePCC'))
                    lines.append(
                        f"| {name[:24]} | {n} | {p} | {avg_u:.1f} | {avg_dup*100:.1f}% | {esc} |")
                lines.append("")
            except Exception as e:
                lines.extend([f"### {path.name}", "", f"(error parsing report: {e})", ""]) 
        markdown_report += "\n" + "\n".join(lines)

    # Save to file
    output_path = results_dir / "01_DETAILED_ANALYSIS.md"
    with open(output_path, 'w') as f:
        f.write(markdown_report)

    print(f"✅ Detailed analysis saved to: {output_path}")
    print()

    # Print summary to console
    print("=" * 70)
    print("ANALYSIS SUMMARY")
    print("=" * 70)
    print()

    total_tests = sum(a['total_runs'] for a in analyses)
    total_passed = sum(a['successful_runs'] for a in analyses)
    overall_rate = (total_passed / max(1, total_tests)) * 100

    print(f"Total Tests: {total_tests:,}")
    print(f"Overall Success Rate: {overall_rate:.1f}%")
    print()
    print("Suite Performance:")
    for analysis in analyses:
        status = "✅" if analysis['success_rate'] >= 80 else "⚠️" if analysis['success_rate'] >= 60 else "❌"
        print(f"  {status} {analysis['suite_name']:<30} {analysis['success_rate']:>6.1f}%")
    print()

if __name__ == '__main__':
    main()
