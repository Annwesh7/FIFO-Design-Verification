import os
import re

LOG_DIR = "FIFO Logs"
PASS_THRESHOLD = 60.0  # Coverage must exceed this percentage

results = []

for filename in sorted(os.listdir(LOG_DIR)):
    if not filename.endswith(".log"):
        continue

    with open(os.path.join(LOG_DIR, filename)) as f:
        log = f.read()

    # Extract fields
    seed_match      = re.search(r"Running with seed = (\d+)", log)
    verdict_match   = re.search(r"(Pass|Not Pass), no\. of errors = (\d+)", log)
    coverage_match  = re.search(r"Coverage: ([\d.]+)%", log)
    assertion_count = len(re.findall(r"started at \d+ns failed at", log))

    seed     = int(seed_match.group(1))     if seed_match     else -1
    sb_pass  = (verdict_match.group(1) == "Pass") if verdict_match else False
    errors   = int(verdict_match.group(2))  if verdict_match else -1
    coverage = float(coverage_match.group(1)) if coverage_match else 0.0

    # Apply the pass criteria
    overall_pass = sb_pass and (assertion_count == 0) and (coverage > PASS_THRESHOLD)

    results.append({
        "seed":       seed,
        "sb_pass":    sb_pass,
        "errors":     errors,
        "asserts":    assertion_count,
        "coverage":   coverage,
        "verdict":    "PASS" if overall_pass else "FAIL",
    })

# Per-seed table
print(f"{'Seed':>6}  {'Scoreboard':>10}  {'Errors':>6}  {'Asserts':>7}  {'Coverage':>8}  {'Verdict':>7}")
print("-" * 60)
for r in results:
    sb = "Pass" if r["sb_pass"] else "FAIL"
    print(f"{r['seed']:>6}  {sb:>10}  {r['errors']:>6}  {r['asserts']:>7}  {r['coverage']:>7.2f}%  {r['verdict']:>7}")

# Aggregate
total  = len(results)
passed = sum(1 for r in results if r["verdict"] == "PASS")
mean_coverage = sum(r["coverage"] for r in results) / total if total else 0
min_coverage  = min((r["coverage"] for r in results), default=0)
max_coverage  = max((r["coverage"] for r in results), default=0)

print("-" * 60)
print(f"Summary: {passed}/{total} passed")
print(f"Coverage: mean={mean_coverage:.2f}%, min={min_coverage:.2f}%, max={max_coverage:.2f}%")

with open("regression_report.txt", "w") as f:
    f.write(f"Summary: {passed}/{total} passed\n")
    f.write(f"Coverage: mean={mean_coverage:.2f}%, min={min_coverage:.2f}%, max={max_coverage:.2f}%\n")