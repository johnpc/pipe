"""Average CPU % over a window vs the budget; exit 1 when over.

argv: cpu_start cpu_end wall_start wall_end budget_percent
Also appends the result to the GitHub job summary when running in Actions."""
import os
import sys

c0, c1, t0, t1, budget = (float(x) for x in sys.argv[1:6])
percent = (c1 - c0) / max(t1 - t0, 1) * 100
ok = percent <= budget
line = (f"{'✅' if ok else '❌'} Background CPU {percent:.1f}% over {t1 - t0:.0f}s "
        f"(budget {budget:.0f}%; iOS kills at 80% on a phone)")
print(line)
summary = os.environ.get("GITHUB_STEP_SUMMARY")
if summary:
    with open(summary, "a") as f:
        f.write(line + "\n")
sys.exit(0 if ok else 1)
