"""Personalization evaluation: same question, paired user profiles.

For each pair, profile A and profile B are sent the SAME question (real
/chatbot prompt path, real OpenAI calls) and both real responses are stored.
Two complementary measures are used to check whether the responses actually
differ according to context, rather than being near-identical templated text:

  1. response_similarity: TF-IDF cosine similarity between response A and B
     (scikit-learn, already a project dependency). Lower = more different.
     Objective and reproducible, but says nothing about *whether* the
     difference is meaningful.
  2. personalization_delta_score (1-5): a second, clearly-labelled AUTOMATED
     judge call asked whether the differences it sees are the kind you'd
     expect given the two profiles (not just paraphrasing). Qualitative
     complement to (1), because text similarity alone does not prove real
     personalization.

Usage:
    python evaluation/evaluate_personalization.py
    python evaluation/evaluate_personalization.py --limit 2   # smoke test

Output:
    evaluation/results/personalization_results.json
    evaluation/results/personalization_results.csv
"""
import argparse
import csv
import json
from datetime import datetime, timezone

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

import common

JUDGE_MODEL = 'gpt-4o-mini'

DELTA_JUDGE_SYSTEM_PROMPT = (
    'You compare two replies from the same menstrual-health assistant, given to the SAME '
    'question but from two users with different profiles (shown below). Judge whether reply B '
    'meaningfully differs from reply A in ways that reflect the profile differences (e.g. '
    'different exercise/rest suggestions for different stress or exercise levels), rather than '
    'being near-identical generic text with different names swapped in.\n\n'
    'Score personalization_delta_score 1-5: 5 = clearly and appropriately different given the '
    'profiles, 1 = essentially the same generic advice despite very different profiles.\n\n'
    'Respond with ONLY a JSON object, no markdown fences, no extra text, in exactly this shape:\n'
    '{"personalization_delta_score": <1-5 int>, "comments": "<one short sentence naming the key difference or lack thereof>"}'
)

# Paired scenarios: same question, contrasting profiles. Kept minimal/lean
# per profile (only fields build_context_summary uses).
PERSONALIZATION_PAIRS = [
    {
        'id': 'PAIR01',
        'category': 'stress_sleep_exercise_contrast',
        'question': 'Give me recommendations for today.',
        'profile_a': {
            'label': 'low stress, good sleep, regular exercise',
            'profile': {'username': 'User A', 'age': 27, 'avg_cycle_length': 28, 'avg_period_duration': 5,
                        'stress_level': 1, 'sleep_hours': 8, 'exercise_days': 5, 'fitness_level': 'high'},
            'prediction': {'current_phase': 'Follicular', 'phase_description': 'Energy rising. Good time for strength training.',
                           'cycle_day': 9, 'days_until_period': 19, 'next_period': '2026-08-29',
                           'fertile_window': '18 Aug – 24 Aug 2026', 'ovulation_day': '23 Aug 2026', 'cycle_length': 28},
            'symptom_logs': [], 'today': '2026-08-10',
        },
        'profile_b': {
            'label': 'high stress, poor sleep, little exercise',
            'profile': {'username': 'User B', 'age': 27, 'avg_cycle_length': 28, 'avg_period_duration': 5,
                        'stress_level': 5, 'sleep_hours': 4.5, 'exercise_days': 0, 'fitness_level': 'low'},
            'prediction': {'current_phase': 'Follicular', 'phase_description': 'Energy rising. Good time for strength training.',
                           'cycle_day': 9, 'days_until_period': 19, 'next_period': '2026-08-29',
                           'fertile_window': '18 Aug – 24 Aug 2026', 'ovulation_day': '23 Aug 2026', 'cycle_length': 28},
            'symptom_logs': [], 'today': '2026-08-10',
        },
    },
    {
        'id': 'PAIR02',
        'category': 'age_contrast_teen_vs_perimenopause',
        'question': 'What should I know about my cycle this week?',
        'profile_a': {
            'label': 'teen, age 16',
            'profile': {'username': 'User A', 'age': 16, 'avg_cycle_length': 32, 'avg_period_duration': 6,
                        'stress_level': 2, 'sleep_hours': 8, 'exercise_days': 2, 'fitness_level': 'average'},
            'prediction': {'current_phase': 'Follicular', 'phase_description': 'Energy rising. Good time for strength training.',
                           'cycle_day': 6, 'days_until_period': 26, 'next_period': '2026-09-05',
                           'fertile_window': '20 Aug – 26 Aug 2026', 'ovulation_day': '25 Aug 2026', 'cycle_length': 32},
            'symptom_logs': [], 'today': '2026-08-10',
        },
        'profile_b': {
            'label': 'perimenopausal, age 47',
            'profile': {'username': 'User B', 'age': 47, 'avg_cycle_length': 21, 'avg_period_duration': 3,
                        'stress_level': 2, 'sleep_hours': 8, 'exercise_days': 2, 'fitness_level': 'average'},
            'prediction': {'current_phase': 'Follicular', 'phase_description': 'Energy rising. Good time for strength training.',
                           'cycle_day': 5, 'days_until_period': 16, 'next_period': '2026-08-26',
                           'fertile_window': '13 Aug – 19 Aug 2026', 'ovulation_day': '18 Aug 2026', 'cycle_length': 21},
            'symptom_logs': [], 'today': '2026-08-10',
        },
    },
    {
        'id': 'PAIR03',
        'category': 'phase_contrast_menstrual_vs_fertile',
        'question': 'Give me recommendations for today.',
        'profile_a': {
            'label': 'currently menstruating',
            'profile': {'username': 'User A', 'age': 29, 'avg_cycle_length': 28, 'avg_period_duration': 5,
                        'stress_level': 2, 'sleep_hours': 7, 'exercise_days': 3, 'fitness_level': 'average'},
            'prediction': {'current_phase': 'Menstrual', 'phase_description': 'Your period is active. Rest and stay hydrated.',
                           'cycle_day': 2, 'days_until_period': 27, 'next_period': '2026-09-06',
                           'fertile_window': '18 Aug – 24 Aug 2026', 'ovulation_day': '23 Aug 2026', 'cycle_length': 28},
            'symptom_logs': [{'date': '2026-08-09', 'symptoms': ['cramps', 'fatigue'], 'mood': 'Tired', 'flow': 'Heavy', 'notes': ''}],
            'today': '2026-08-10',
        },
        'profile_b': {
            'label': 'currently in fertile window',
            'profile': {'username': 'User B', 'age': 29, 'avg_cycle_length': 28, 'avg_period_duration': 5,
                        'stress_level': 2, 'sleep_hours': 7, 'exercise_days': 3, 'fitness_level': 'average'},
            'prediction': {'current_phase': 'Fertility', 'phase_description': 'Peak fertility window. Energy is at its highest.',
                           'cycle_day': 14, 'days_until_period': 14, 'next_period': '2026-08-24',
                           'fertile_window': '09 Aug – 15 Aug 2026', 'ovulation_day': '14 Aug 2026', 'cycle_length': 28},
            'symptom_logs': [{'date': '2026-08-09', 'symptoms': [], 'mood': 'Great', 'flow': 'None', 'notes': ''}],
            'today': '2026-08-10',
        },
    },
    {
        'id': 'PAIR04',
        'category': 'symptom_burden_contrast',
        'question': 'How am I doing this week and what should I focus on?',
        'profile_a': {
            'label': 'no notable symptoms',
            'profile': {'username': 'User A', 'age': 25, 'avg_cycle_length': 28, 'avg_period_duration': 5,
                        'stress_level': 2, 'sleep_hours': 7.5, 'exercise_days': 3, 'fitness_level': 'average'},
            'prediction': {'current_phase': 'Luteal', 'phase_description': 'Progesterone rising. Prefer low-impact exercise.',
                           'cycle_day': 20, 'days_until_period': 8, 'next_period': '2026-08-18',
                           'fertile_window': 'already passed this cycle', 'ovulation_day': '29 Jul 2026', 'cycle_length': 28},
            'symptom_logs': [{'date': '2026-08-09', 'symptoms': [], 'mood': 'Good', 'flow': 'None', 'notes': ''}],
            'today': '2026-08-10',
        },
        'profile_b': {
            'label': 'heavy PMS symptom burden',
            'profile': {'username': 'User B', 'age': 25, 'avg_cycle_length': 28, 'avg_period_duration': 5,
                        'stress_level': 2, 'sleep_hours': 7.5, 'exercise_days': 3, 'fitness_level': 'average'},
            'prediction': {'current_phase': 'Luteal', 'phase_description': 'Progesterone rising. Prefer low-impact exercise.',
                           'cycle_day': 20, 'days_until_period': 8, 'next_period': '2026-08-18',
                           'fertile_window': 'already passed this cycle', 'ovulation_day': '29 Jul 2026', 'cycle_length': 28},
            'symptom_logs': [{'date': '2026-08-09', 'symptoms': ['cramps', 'sorebreasts', 'bloating', 'moodswing', 'headache'],
                               'mood': 'Miserable', 'flow': 'None', 'notes': 'PMS is really bad this month'}],
            'today': '2026-08-10',
        },
    },
]


def tfidf_cosine_similarity(text_a: str, text_b: str) -> float:
    vectorizer = TfidfVectorizer(stop_words='english')
    matrix = vectorizer.fit_transform([text_a, text_b])
    return float(cosine_similarity(matrix[0], matrix[1])[0, 0])


def judge_delta(pair: dict, response_a: str, response_b: str) -> dict:
    user_content = (
        f"Question asked to both: {pair['question']}\n\n"
        f"Profile A ({pair['profile_a']['label']}): {common.build_context_summary(pair['profile_a'])}\n"
        f"Reply A:\n{response_a}\n\n"
        f"Profile B ({pair['profile_b']['label']}): {common.build_context_summary(pair['profile_b'])}\n"
        f"Reply B:\n{response_b}"
    )
    return common.call_judge(DELTA_JUDGE_SYSTEM_PROMPT, user_content)


def run_pair(pair: dict) -> dict:
    record = {
        'id': pair['id'],
        'category': pair['category'],
        'question': pair['question'],
        'profile_a_label': pair['profile_a']['label'],
        'profile_b_label': pair['profile_b']['label'],
        'response_a': None,
        'response_b': None,
        'generation_error': None,
        'response_similarity': None,
        'personalization_delta_score': None,
        'judge_comments': None,
        'judge_error': None,
        'automated_evaluation': True,
        'judge_model': JUDGE_MODEL,
        'timestamp': datetime.now(timezone.utc).isoformat(),
    }

    try:
        record['response_a'] = common.call_chatbot(pair['profile_a'], message=pair['question'])
        record['response_b'] = common.call_chatbot(pair['profile_b'], message=pair['question'])
    except Exception as e:
        record['generation_error'] = str(e)
        return record

    record['response_similarity'] = round(
        tfidf_cosine_similarity(record['response_a'], record['response_b']), 4
    )

    judged = judge_delta(pair, record['response_a'], record['response_b'])
    if 'error' in judged or 'personalization_delta_score' not in judged:
        record['judge_error'] = judged.get('error', 'judge_response_missing_criteria')
        return record

    record['personalization_delta_score'] = judged['personalization_delta_score']
    record['judge_comments'] = judged.get('comments')
    return record


def write_outputs(records, json_path, csv_path):
    json_path.write_text(json.dumps(records, indent=2), encoding='utf-8')
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow([
            'id', 'category', 'question', 'profile_a_label', 'profile_b_label',
            'response_a', 'response_b', 'response_similarity', 'personalization_delta_score',
            'judge_comments', 'automated_evaluation', 'judge_model',
            'generation_error', 'judge_error', 'timestamp',
        ])
        for r in records:
            writer.writerow([
                r['id'], r['category'], r['question'], r['profile_a_label'], r['profile_b_label'],
                r.get('response_a') or '', r.get('response_b') or '',
                r.get('response_similarity', ''), r.get('personalization_delta_score', ''),
                r.get('judge_comments') or '', r['automated_evaluation'], r['judge_model'],
                r.get('generation_error') or '', r.get('judge_error') or '', r['timestamp'],
            ])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--limit', type=int, default=None)
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()

    pairs = PERSONALIZATION_PAIRS[:args.limit] if args.limit else PERSONALIZATION_PAIRS

    json_path = common.RESULTS_DIR / 'personalization_results.json'
    csv_path = common.RESULTS_DIR / 'personalization_results.csv'
    common.RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    cache = {}
    if not args.force and json_path.exists():
        cache = {r['id']: r for r in json.loads(json_path.read_text(encoding='utf-8'))}

    records = dict(cache)
    for pair in pairs:
        if pair['id'] in cache and not args.force:
            print(f"[skip] {pair['id']} already cached")
            continue
        print(f"[run]  {pair['id']} ({pair['category']})...")
        record = run_pair(pair)
        records[pair['id']] = record
        if record['generation_error']:
            print(f"       generation error: {record['generation_error']}")
        else:
            print(f"       response_similarity={record['response_similarity']}, "
                  f"personalization_delta_score={record['personalization_delta_score']}")
        write_outputs(list(records.values()), json_path, csv_path)

    scored = [r for r in records.values() if r.get('response_similarity') is not None]
    if scored:
        avg_sim = sum(r['response_similarity'] for r in scored) / len(scored)
        deltas = [r['personalization_delta_score'] for r in scored if r.get('personalization_delta_score')]
        print(f'\n{len(scored)}/{len(records)} pairs generated. Average TF-IDF similarity: {avg_sim:.3f} (lower = more different)')
        if deltas:
            print(f'Average personalization_delta_score: {sum(deltas)/len(deltas):.2f}/5')
    print(f'Results written to {json_path} and {csv_path}')


if __name__ == '__main__':
    main()
