"""Human validation of the automated GPT-4o-mini judge used in evaluate_llm.py.

An LLM grading its own kind of output ("GPT judging GPT") is not equivalent
to human evaluation. This script lets a real person score a representative
sample of cases and reports how closely those scores match the automated
judge's scores, so the FYP report can state actual agreement rather than
just asserting the automated judge is trustworthy.

Two steps:

  1. generate-template — picks ~8-10 cases spread across all four endpoints
     from the already-generated evaluation/results/llm_results.json and
     writes evaluation/results/human_validation_template.csv with the
     scenario + generated response and BLANK score columns for you to fill
     in. The automated scores are deliberately left out of this file so
     filling it in is a blind scoring pass (not anchored on the AI's own
     scores).

  2. compare — reads your filled-in CSV back, looks up the matching
     automated scores by case id, and writes
     evaluation/results/human_validation_results.json/csv with both sets of
     scores side by side plus per-criterion agreement stats (mean absolute
     difference, exact-match rate, within-1-point rate). Cases you left
     blank are skipped.

Usage:
    python evaluation/human_validation.py generate-template [--n 9]
    # ... open evaluation/results/human_validation_template.csv, fill in the
    #     human_* columns (1-5 ints) and human_comments, save it ...
    python evaluation/human_validation.py compare
"""
import argparse
import csv
import json

import common

CRITERIA = ('relevance', 'personalization', 'helpfulness', 'clarity', 'safety')
ENDPOINTS = ('recommendations', 'weekly_summary', 'wellness_plan', 'chatbot')

TEMPLATE_PATH = common.RESULTS_DIR / 'human_validation_template.csv'
TEMPLATE_XLSX_PATH = common.RESULTS_DIR / 'human_validation_template.xlsx'
RESULTS_JSON_PATH = common.RESULTS_DIR / 'human_validation_results.json'
RESULTS_CSV_PATH = common.RESULTS_DIR / 'human_validation_results.csv'
LLM_RESULTS_PATH = common.RESULTS_DIR / 'llm_results.json'


def pick_sample(records: list[dict], n: int) -> list[dict]:
    """Deterministic, endpoint-spread sample: round-robin across endpoints
    in case-id order until n cases are picked, skipping unscored cases."""
    scored = [r for r in records if r.get('overall_score') is not None]
    by_endpoint = {ep: [r for r in scored if r['endpoint'] == ep] for ep in ENDPOINTS}
    for bucket in by_endpoint.values():
        bucket.sort(key=lambda r: r['id'])

    sample, i = [], 0
    while len(sample) < n and any(by_endpoint.values()):
        for ep in ENDPOINTS:
            if len(sample) >= n:
                break
            bucket = by_endpoint[ep]
            if i < len(bucket):
                sample.append(bucket[i])
        i += 1
    return sample[:n]


def generate_template(n: int):
    if not LLM_RESULTS_PATH.exists():
        raise SystemExit(f'{LLM_RESULTS_PATH} not found — run evaluate_llm.py first.')
    records = json.loads(LLM_RESULTS_PATH.read_text(encoding='utf-8'))
    sample = pick_sample(records, n)
    if not sample:
        raise SystemExit('No scored cases available to sample from.')

    common.RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    with open(TEMPLATE_PATH, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow([
            'id', 'category', 'endpoint', 'question', 'generated_response',
            'human_relevance', 'human_personalization', 'human_helpfulness',
            'human_clarity', 'human_safety', 'human_comments',
        ])
        for r in sample:
            writer.writerow([
                r['id'], r['category'], r['endpoint'], r.get('question') or '',
                r['generated_response'], '', '', '', '', '', '',
            ])

    print(f'Wrote {len(sample)} cases to {TEMPLATE_PATH}')
    print('Open it, score each row 1-5 in the human_* columns, save, then run:')
    print('  python evaluation/human_validation.py compare')


def _load_csv_rows():
    with open(TEMPLATE_PATH, newline='', encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))


def _load_xlsx_rows():
    import openpyxl
    wb = openpyxl.load_workbook(TEMPLATE_XLSX_PATH, data_only=True)
    ws = wb.active
    rows_iter = ws.iter_rows(values_only=True)
    headers = list(next(rows_iter))
    return [dict(zip(headers, row)) for row in rows_iter]


def load_template_rows():
    """Reads whichever template the user actually filled in. If both exist,
    uses the one modified more recently (Excel is the natural way to fill
    this in, but the plain CSV still works if that's what got edited)."""
    have_csv = TEMPLATE_PATH.exists()
    have_xlsx = TEMPLATE_XLSX_PATH.exists()
    if not have_csv and not have_xlsx:
        raise SystemExit(f'Neither {TEMPLATE_PATH} nor {TEMPLATE_XLSX_PATH} found — run generate-template first.')
    if have_xlsx and (not have_csv or TEMPLATE_XLSX_PATH.stat().st_mtime >= TEMPLATE_PATH.stat().st_mtime):
        print(f'Reading scores from {TEMPLATE_XLSX_PATH}')
        return _load_xlsx_rows()
    print(f'Reading scores from {TEMPLATE_PATH}')
    return _load_csv_rows()


def compare():
    if not LLM_RESULTS_PATH.exists():
        raise SystemExit(f'{LLM_RESULTS_PATH} not found — run evaluate_llm.py first.')

    automated_by_id = {r['id']: r for r in json.loads(LLM_RESULTS_PATH.read_text(encoding='utf-8'))}
    rows = load_template_rows()

    comparisons = []
    for row in rows:
        human_scores = {}
        for c in CRITERIA:
            raw = row.get(f'human_{c}')
            val = '' if raw is None else str(raw).strip()
            if val == '':
                human_scores = None
                break
            try:
                human_scores[c] = int(float(val))
            except ValueError:
                raise SystemExit(f"Row {row['id']}: human_{c}='{val}' is not an integer 1-5.")
        if human_scores is None:
            print(f"[skip] {row['id']}: not yet scored")
            continue

        automated = automated_by_id.get(row['id'])
        if not automated or automated.get('scores') is None:
            print(f"[skip] {row['id']}: no automated score on record")
            continue

        auto_scores = automated['scores']
        diffs = {c: human_scores[c] - auto_scores[c] for c in CRITERIA}
        comparisons.append({
            'id': row['id'],
            'category': row['category'],
            'endpoint': row['endpoint'],
            'human_scores': human_scores,
            'automated_scores': auto_scores,
            'human_overall': round(sum(human_scores.values()) / len(CRITERIA), 2),
            'automated_overall': automated['overall_score'],
            'diffs': diffs,
            'human_comments': row.get('human_comments') or '',
        })

    if not comparisons:
        print('No completed rows to compare yet. Fill in the human_* columns and re-run.')
        return

    agreement = {}
    for c in CRITERIA:
        abs_diffs = [abs(cmp['diffs'][c]) for cmp in comparisons]
        agreement[c] = {
            'mean_absolute_difference': round(sum(abs_diffs) / len(abs_diffs), 3),
            'exact_match_rate': round(sum(d == 0 for d in abs_diffs) / len(abs_diffs), 3),
            'within_1_point_rate': round(sum(d <= 1 for d in abs_diffs) / len(abs_diffs), 3),
        }

    output = {
        'n_compared': len(comparisons),
        'agreement_by_criterion': agreement,
        'comparisons': comparisons,
        'note': (
            'human_* fields were manually entered by the developer; automated_* fields came '
            'from the GPT-4o-mini judge in evaluate_llm.py. This is a small-sample agreement '
            'check, not a claim that the automated judge equals human evaluation.'
        ),
    }
    RESULTS_JSON_PATH.write_text(json.dumps(output, indent=2), encoding='utf-8')

    with open(RESULTS_CSV_PATH, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        header = ['id', 'category', 'endpoint']
        for c in CRITERIA:
            header += [f'human_{c}', f'automated_{c}', f'diff_{c}']
        header += ['human_overall', 'automated_overall', 'human_comments']
        writer.writerow(header)
        for cmp in comparisons:
            row = [cmp['id'], cmp['category'], cmp['endpoint']]
            for c in CRITERIA:
                row += [cmp['human_scores'][c], cmp['automated_scores'][c], cmp['diffs'][c]]
            row += [cmp['human_overall'], cmp['automated_overall'], cmp['human_comments']]
            writer.writerow(row)

    print(f'\nCompared {len(comparisons)} cases.')
    for c in CRITERIA:
        a = agreement[c]
        print(f"  {c:16s} mean|diff|={a['mean_absolute_difference']}  exact_match={a['exact_match_rate']:.0%}  within_1={a['within_1_point_rate']:.0%}")
    print(f'\nResults written to {RESULTS_JSON_PATH} and {RESULTS_CSV_PATH}')


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest='command', required=True)

    gen = sub.add_parser('generate-template')
    gen.add_argument('--n', type=int, default=9, help='number of cases to sample (default 9)')

    sub.add_parser('compare')

    args = parser.parse_args()
    if args.command == 'generate-template':
        generate_template(args.n)
    elif args.command == 'compare':
        compare()


if __name__ == '__main__':
    main()
