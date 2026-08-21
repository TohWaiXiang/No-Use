"""Shared helpers for the LUNA evaluation scripts.

Not production code — used only by evaluation/*.py so all the harnesses
build LLM prompts exactly the way the real endpoints in main.py do, instead
of a hand-copied version that could drift out of sync.

Importing `main` runs its module-level setup (loads the .pkl models,
initializes Firebase Admin, reads OPENAI_API_KEY from .env) because that's
where the real prompts and _call_openai() live. Evaluation never calls
Firestore itself — user context is built from the test-case JSON below
instead of a live user_id — but the same .env / firebase_config the backend
uses must be present for the import to succeed.
"""
import json
import os
import sys
from datetime import date
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
EVAL_DIR = Path(__file__).resolve().parent
RESULTS_DIR = EVAL_DIR / 'results'

os.chdir(BACKEND_DIR)  # main.py resolves model/firebase paths relative to CWD
sys.path.insert(0, str(BACKEND_DIR))

import main as luna  # noqa: E402


def load_test_cases(path=None):
    path = Path(path) if path else EVAL_DIR / 'test_cases.json'
    return json.loads(path.read_text(encoding='utf-8'))


def build_context_summary(scenario: dict) -> str:
    """Mirrors main._build_chat_context's text format field-for-field, but
    sourced from a test scenario dict instead of a Firestore user doc."""
    p = scenario['profile']
    parts = [
        f"User profile: name={p.get('username', 'Test User')}, age={p['age']}, "
        f"avg cycle length={p['avg_cycle_length']} days, "
        f"avg period duration={p['avg_period_duration']} days, "
        f"stress level={p['stress_level']}, sleep hours={p['sleep_hours']}, "
        f"exercise days/week={p['exercise_days']}, fitness level={p.get('fitness_level', 'average')}."
    ]
    if p.get('pss10_score') is not None:
        parts.append(
            f"Latest monthly check-in: PSS-10 perceived stress score="
            f"{p['pss10_score']}/40, PSQI sleep quality score="
            f"{p.get('psqi_global_score')}/21, hormonal-imbalance risk="
            f"{p.get('hormonal_risk')} (assessed {p.get('hormonal_assessment_date')})."
        )

    pred = scenario.get('prediction')
    if pred:
        parts.append(
            f"Current cycle prediction: phase={pred.get('current_phase')}, "
            f"phase description={pred.get('phase_description', '')}, "
            f"current cycle day={pred.get('cycle_day')}, "
            f"days until next period={pred.get('days_until_period')}, "
            f"next period={pred.get('next_period')}, "
            f"fertile window={pred.get('fertile_window')}, "
            f"ovulation day={pred.get('ovulation_day')}, "
            f"cycle length={pred.get('cycle_length')}."
        )

    logs = scenario.get('symptom_logs') or []
    if logs:
        parts.append('Recent symptom logs (most recent first):')
        for log in sorted(logs, key=lambda l: l['date'], reverse=True)[:5]:
            symptoms = ', '.join(log.get('symptoms') or []) or 'none'
            parts.append(
                f"- {log.get('date')}: mood={log.get('mood')}, flow={log.get('flow', 'none')}, "
                f"symptoms={symptoms}, notes={log.get('notes', '')}"
            )

    return '\n'.join(parts)


def build_trend_summary(scenario: dict) -> str:
    logs = scenario.get('symptom_logs') or []
    if not logs:
        return 'No symptom logs available yet this month.'
    today = date.fromisoformat(scenario.get('today', date.today().isoformat()))
    return luna._trend_stats_from_logs(logs, today)


def call_recommendations(scenario: dict) -> str:
    context = build_context_summary(scenario)
    messages = [{'role': 'system', 'content': f'{luna.RECOMMENDATIONS_SYSTEM_PROMPT}\n\n{context}'}]
    return luna._call_openai(messages)


def call_weekly_summary(scenario: dict) -> str:
    context = build_context_summary(scenario)
    trend = build_trend_summary(scenario)
    messages = [{'role': 'system', 'content': f'{luna.WEEKLY_SUMMARY_SYSTEM_PROMPT}\n\n{context}\n\n{trend}'}]
    return luna._call_openai(messages)


def call_wellness_plan(scenario: dict) -> str:
    context = build_context_summary(scenario)
    trend = build_trend_summary(scenario)
    messages = [{'role': 'system', 'content': f'{luna.WELLNESS_PLAN_SYSTEM_PROMPT}\n\n{context}\n\n{trend}'}]
    return luna._call_openai(messages)


def call_chatbot(scenario: dict, message: str = None) -> str:
    context = build_context_summary(scenario)
    user_message = message or scenario.get('question') or 'Give me recommendations for today.'
    messages = [
        {'role': 'system', 'content': f'{luna.CHAT_SYSTEM_PROMPT}\n\n{context}'},
        {'role': 'user', 'content': user_message},
    ]
    raw = luna._call_openai(messages)
    # Mirror the /chatbot endpoint's reply-shaping so an infographic JSON
    # response is captured as readable text instead of raw JSON.
    try:
        parsed = json.loads(raw)
        if (
            isinstance(parsed, dict)
            and parsed.get('type') == 'infographic'
            and parsed.get('chart') in luna.KNOWN_CHARTS
        ):
            return f"[infographic:{parsed['chart']}] {json.dumps(parsed.get('data'))}"
    except (json.JSONDecodeError, TypeError):
        pass
    return raw


ENDPOINT_CALLERS = {
    'recommendations': call_recommendations,
    'weekly_summary': call_weekly_summary,
    'wellness_plan': call_wellness_plan,
    'chatbot': call_chatbot,
}


def call_endpoint(endpoint: str, scenario: dict, message: str = None) -> str:
    if endpoint == 'chatbot':
        return call_chatbot(scenario, message=message)
    return ENDPOINT_CALLERS[endpoint](scenario)


def call_judge(system_prompt: str, user_content: str, retries: int = 1) -> dict:
    """Calls GPT-4o-mini as an automated judge and parses a strict-JSON reply.
    Returns {'error': ...} instead of fabricating scores if the judge's
    output isn't valid JSON after retrying."""
    messages = [
        {'role': 'system', 'content': system_prompt},
        {'role': 'user', 'content': user_content},
    ]
    last_raw = None
    for _ in range(retries + 1):
        raw = luna._call_openai(messages)
        last_raw = raw
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            continue
    return {'error': 'judge_did_not_return_valid_json', 'raw_response': last_raw}
