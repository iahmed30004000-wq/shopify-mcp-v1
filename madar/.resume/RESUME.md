# Resume point (usage-limit checkpoint 07:20 UTC; refreshed after a container restart)

All agents were stopped deliberately at ~95 % of the 5-hour usage limit.
This commit is a WORK-IN-PROGRESS checkpoint (`[skip ci]`): several
packages below are PARTIAL and may not compile or pass tests yet. Nothing
here is "done" unless listed as done. Last verified, CI-green commit:
08f9cb1 (APK madar-apk-10 = c8ea1af + foundation; feature APK: madar-apk-9).

## Done and verified before this checkpoint
- Phases 0–3 (pushed, CI green).
- Phase 4 builders finished (not yet integrated/reviewed):
  meds (lib/features/health/meds), record (lib/features/health/record),
  wellbeing (lib/features/health/wellbeing).

## Interrupted – resume each by re-running its builder with
## "a previous attempt left partial work in your folder: review it,
##  verify everything, finish what is missing; do not assume anything works"
| Package | Owned paths | State |
|---|---|---|
| Health integration | lib/features/health/hub, routing, settings, orbit planet page, 99_health_hub.json | started, partial |
| Health review | – | not started |
| Money ledger | lib/features/money/ledger, a1_money_ledger.json | partial |
| Money budget | lib/features/money/budget, a2_money_budget.json | partial |
| Money goals | lib/features/money/goals, a3_money_goals.json | partial (analyze errors at stop) |
| Work | lib/features/work, b1_work.json | partial |
| Family | lib/features/family, b2_family.json | partial |
| Travel | lib/features/travel, b3_travel.json | partial |
| Growth | lib/features/growth, b4_growth.json | partial |
| Body | lib/features/body, b5_body.json | partial |
| Hotfix: auto fingerprint prompt + orbit reset view | .resume/hotfix_lock_orbit.patch (apply onto 08f9cb1 in a clean worktree: `git apply`) | partial, not verified |
| Film Reel Engine (Phase 7) | – | planned, not started; `flame` added to pubspec |

## After resuming
1. Finish + verify the hotfix first (ship as its own APK).
2. Finish builders → Health integration + review → Money integration +
   review → Life integration + review (shared files: one at a time).
3. Delete this .resume folder once everything is integrated and green.
