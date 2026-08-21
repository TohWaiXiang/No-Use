from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime, timedelta
import joblib
import numpy as np
import firebase_admin
from firebase_admin import credentials, firestore
import base64
import os
import re
import json
import requests
import time
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from dotenv import load_dotenv

load_dotenv()
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')
# Locally the key file sits in firebase_config/ (gitignored). On a host like
# Railway there's no such file in the deploy, so the same JSON is provided
# via an env var instead — base64-encoded, because pasting the raw JSON into
# a dashboard text box mangles the multi-line private_key field's newlines.
_firebase_json_env = os.getenv('FIREBASE_SERVICE_ACCOUNT_JSON')
if _firebase_json_env:
    decoded = base64.b64decode(_firebase_json_env).decode()
    cred = credentials.Certificate(json.loads(decoded))
else:
    cred = credentials.Certificate('firebase_config/serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

# Firestore's own `timeout=` kwarg only bounds the RPC itself — it does NOT
# bound credential/token-refresh retries. If the service account key is
# invalid or expired, a call can hang for the client library's internal
# ~300s retry budget regardless of any per-call timeout. Every blocking
# Firestore call in this file should go through _ff() so a credential
# outage degrades in seconds instead of minutes.
_FIRESTORE_TIMEOUT = 8
_firestore_pool = ThreadPoolExecutor(max_workers=16)


def _ff(fn, default=None, timeout=_FIRESTORE_TIMEOUT, critical=False):
    """critical=True raises a 503 instead of swallowing, for callers where a
    failed fetch must not be presented to the user as "you have no data"."""
    try:
        return _firestore_pool.submit(fn).result(timeout=timeout)
    except Exception as e:
        print('Firestore call failed/timed out:', e)
        if critical:
            raise HTTPException(
                status_code=503,
                detail='Could not reach your health data right now. Please try again.',
            )
        return default

model_bundle        = joblib.load('model/cycle_model.pkl')
model               = model_bundle['model']
label_encoder       = model_bundle['label_encoder']
flow_color_encoder  = model_bundle['flow_color_encoder']
feature_order       = model_bundle['feature_order']

length_bundle        = joblib.load('model/cycle_length_model.pkl')
length_model         = length_bundle['model']
length_feature_order = length_bundle['feature_order']

app = FastAPI(title='Luna Health API')

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)

class UserProfile(BaseModel):
    user_id:              str
    username:             str
    email:                str
    age:                  int
    fitness_level:        str
    avg_cycle_length:     float = 28.0
    avg_period_duration:  float = 5.0
    stress_level:         int   = 2
    sleep_hours:          float = 7.0
    exercise_days:        int   = 3

class CycleLog(BaseModel):
    user_id: str
    period_start: str
    period_end: str
    symptoms: list[str]
    mood: str
    stress_level: int
    sleep_hours:float
    exercise_days: int

class PredictRequest(BaseModel):
    user_id: str
    last_period_start: str
    avg_cycle_length: float = 28.0
    avg_period_duration: float = 5.0
    age: int = 25
    # 1-5, derived from the PSS-10/PSQI monthly check-in (see stress_level in
    # profile). Close enough to the 0-5 Likert scale below to feed the same
    # regressor without a separate rescale.
    stress_level: int = 2
    sleep_hours: float = 7.0
    exercise_days: int = 3
    # Likert severity fields below are 0-5 (0 = Not at all, 5 = Very high) unless noted.
    flow_volume: int = 0     # 0-7, see FLOW_VOLUME_SCALE in train_model.py
    flow_color: str = 'Not at all'
    appetite: int = 3
    exerciselevel: int = 3
    headaches: int = 0
    cramps: int = 0
    sorebreasts: int = 0
    fatigue: int = 0
    sleepissue: int = 0
    moodswing: int = 0
    stress: int = 0
    foodcravings: int = 0
    indigestion: int = 0
    bloating: int = 0

class ChatMessage(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    user_id: str
    message: str
    history: list[ChatMessage] = []

PHASE_DESCRIPTIONS = {
    'Menstrual':  'Your period is active. Rest and stay hydrated.',
    'Follicular': 'Energy rising. Good time for strength training.',
    'Fertility':  'Peak fertility window. Energy is at its highest.',
    'Luteal':     'Progesterone rising. Prefer low-impact exercise.',
}

KNOWN_CHARTS = {'cycle_phase', 'fertile_window', 'symptom_trend'}

CHAT_SYSTEM_PROMPT = (
    'You are Luna, a friendly and knowledgeable menstrual health assistant '
    'inside a period-tracking app. Answer questions about cycles, symptoms, '
    'fertility windows, and wellness clearly and concisely. Always remind '
    'users to consult a healthcare professional for personalised medical advice.\n\n'
    'Format plain-text answers as Markdown: **bold** key terms, use bullet or '
    'numbered lists for multi-step or multi-item answers, and short headings only '
    'for longer, multi-section answers.\n\n'
    'Some answers are clearer as a visual. If the user asks about their current '
    'cycle phase, fertile window/ovulation, or a trend in their mood, flow, or '
    'symptoms, and the user context above gives you enough data to fill it in, '
    'respond with ONLY a single JSON object (no markdown fences, no extra text) '
    'in one of these exact shapes (the values below are placeholders showing the '
    'expected type only — you MUST replace every value with the real numbers/labels '
    'from the user context above, never reuse these placeholder values):\n'
    '{"type":"infographic","chart":"cycle_phase","data":{"phase":"<menstrual|follicular|ovulation|luteal>","dayOfCycle":<real current cycle day as int>,"cycleLength":<real cycle length as int>}}\n'
    '{"type":"infographic","chart":"fertile_window","data":{"cycleLength":<int>,"currentDay":<int>,"fertileStartDay":<int>,"fertileEndDay":<int>,"ovulationDay":<int>}}\n'
    '{"type":"infographic","chart":"symptom_trend","data":{"days":[{"label":"<date>","symptomsCount":<int>,"moodLabel":"<optional short text>"}]}}\n'
    'phase is one of: menstrual, follicular, ovulation, luteal (lowercase). '
    'symptomsCount is how many symptoms were logged that day; moodLabel is optional short text. '
    'The user context above states the current cycle day and cycle length explicitly when known — use those exact numbers. '
    'Only use this JSON format when you actually have the underlying data from the context above — '
    'otherwise answer in plain conversational text.'
)
    
@app.get('/')
def root():
    return {'message': 'Luna Health API is running'}

@app.post('/user/create')
def create_user(user: UserProfile):
    ok = _ff(lambda: db.collection('users').document(user.user_id).set({
        'username':            user.username,
        'email':               user.email,
        'age':                 user.age,
        'fitness_level':       user.fitness_level,
        'avg_cycle_length':    user.avg_cycle_length,
        'avg_period_duration': user.avg_period_duration,
        'stress_level':        user.stress_level,
        'sleep_hours':         user.sleep_hours,
        'exercise_days':       user.exercise_days,
        'created_at':          datetime.now().isoformat(),
    }) or True, default=False)
    if not ok:
        raise HTTPException(status_code=503, detail='Could not reach Firestore.')
    return {'status': 'User created', 'user_id': user.user_id}

@app.get('/user/{user_id}')
def get_user(user_id: str):
    doc = _ff(lambda: db.collection('users').document(user_id).get())
    if doc is None:
        raise HTTPException(status_code=503, detail='Could not reach Firestore.')
    if not doc.exists:
        raise HTTPException(status_code=404, detail='User not found')
    return doc.to_dict()

@app.post('/cycle/log')
def log_cycle(log: CycleLog):
    start = datetime.strptime(log.period_start, '%Y-%m-%d')
    end   = datetime.strptime(log.period_end,   '%Y-%m-%d')
    duration = (end - start).days + 1

    ok = _ff(lambda: db.collection('cycle_logs').add({
        'user_id':       log.user_id,
        'period_start':  log.period_start,
        'period_end':    log.period_end,
        'duration':      duration,
        'symptoms':      log.symptoms,
        'mood':          log.mood,
        'stress_level':  log.stress_level,
        'sleep_hours':   log.sleep_hours,
        'exercise_days': log.exercise_days,
        'logged_at':     datetime.now().isoformat(),
    }) or True, default=False)
    if not ok:
        raise HTTPException(status_code=503, detail='Could not reach Firestore.')
    return {'status': 'Cycle logged', 'duration': duration}

@app.get('/cycle/history/{user_id}')
def get_history(user_id: str):
    docs = _ff(
        lambda: list(
            db.collection('cycle_logs')
            .where('user_id', '==', user_id)
            .order_by('period_start', direction=firestore.Query.DESCENDING)
            .stream()
        ),
        default=None,
    )
    if docs is None:
        raise HTTPException(status_code=503, detail='Could not reach Firestore.')
    return [d.to_dict() for d in docs]


@app.post('/predict')
def predict_cycle(req: PredictRequest):
    last_start = datetime.strptime(req.last_period_start, '%Y-%m-%d')

    length_features = {
        'age':          req.age,
        'stress':       req.stress_level,
        'sleepissue':   req.sleepissue,
        'headaches':    req.headaches,
        'cramps':       req.cramps,
        'sorebreasts':  req.sorebreasts,
        'fatigue':      req.fatigue,
        'moodswing':    req.moodswing,
        'foodcravings': req.foodcravings,
        'indigestion':  req.indigestion,
        'bloating':     req.bloating,
    }
    length_x = np.array([[length_features[c] for c in length_feature_order]])
    # Clamp to a physiologically plausible range: the regressor is trained on
    # 71 real cycles and can extrapolate poorly outside that sample.
    predicted_cycle_length = int(round(
        np.clip(length_model.predict(length_x)[0], 15, 60)
    ))

    cycle_length = predicted_cycle_length
    next_period_start = last_start + timedelta(days=cycle_length)
    next_period_end   = next_period_start + timedelta(days=int(req.avg_period_duration))

    ovulation_day   = last_start + timedelta(days=cycle_length - 14)
    fertile_start   = ovulation_day - timedelta(days=5)
    fertile_end     = ovulation_day + timedelta(days=1)

    today       = datetime.now()
    days_passed = (today - last_start).days
    cycle_day   = (days_passed % cycle_length) + 1

    flow_color = req.flow_color if req.flow_color in flow_color_encoder.classes_ else 'Not at all'
    encoded_flow_color = int(flow_color_encoder.transform([flow_color])[0])

    feature_values = {
        'cycle_day':      cycle_day,
        'flow_volume':    req.flow_volume,
        'flow_color':     encoded_flow_color,
        'appetite':       req.appetite,
        'exerciselevel':  req.exerciselevel,
        'headaches':      req.headaches,
        'cramps':         req.cramps,
        'sorebreasts':    req.sorebreasts,
        'fatigue':        req.fatigue,
        'sleepissue':     req.sleepissue,
        'moodswing':      req.moodswing,
        'stress':         req.stress,
        'foodcravings':   req.foodcravings,
        'indigestion':    req.indigestion,
        'bloating':       req.bloating,
    }
    features = np.array([[feature_values[col] for col in feature_order]])

    predicted_encoded = model.predict(features)[0]
    predicted_phase   = label_encoder.inverse_transform([predicted_encoded])[0]
    confidence        = round(float(model.predict_proba(features).max()), 3)

    _ff(lambda: db.collection('users').document(req.user_id)
        .collection('predictions').add({
            'next_period_start': next_period_start.strftime('%Y-%m-%d'),
            'next_period_end': next_period_end.strftime('%Y-%m-%d'),
            'ovulation_day': ovulation_day.strftime('%Y-%m-%d'),
            'fertile_start': fertile_start.strftime('%Y-%m-%d'),
            'fertile_end': fertile_end.strftime('%Y-%m-%d'),
            'current_phase': predicted_phase,
            'phase_confidence': confidence,
            'cycle_day': cycle_day,
            'predicted_cycle_length': predicted_cycle_length,
            'age': req.age,
            'predicted_at': datetime.now().isoformat(),
        }))

    return {
        'next_period_start':      next_period_start.strftime('%d %b %Y'),
        'next_period_start_iso':  next_period_start.strftime('%Y-%m-%d'),
        'next_period_end':        next_period_end.strftime('%d %b %Y'),
        'ovulation_day':          ovulation_day.strftime('%d %b %Y'),
        'fertile_window':         f"{fertile_start.strftime('%d %b')} – {fertile_end.strftime('%d %b %Y')}",
        'current_phase':          predicted_phase,
        'phase_description':      PHASE_DESCRIPTIONS.get(predicted_phase, ''),
        'phase_confidence':       confidence,
        'cycle_day':              cycle_day,
        'predicted_cycle_length': predicted_cycle_length,
    }

def _build_chat_context(user_id: str, critical: bool = False):
    """Pulls this user's Firestore data and returns (context_summary, prediction_dict).

    critical=True (used by the recommendations/summary/wellness-plan cards,
    never by /chatbot) makes a failed symptom/medication log fetch raise a
    503 instead of silently reading as "nothing logged"."""
    parts = []

    user_doc = _ff(lambda: db.collection('users').document(user_id).get())
    profile = user_doc.to_dict() if (user_doc is not None and user_doc.exists) else {}
    if profile:
        parts.append(
            f"User profile: name={profile.get('username')}, age={profile.get('age')}, "
            f"avg cycle length={profile.get('avg_cycle_length')} days, "
            f"avg period duration={profile.get('avg_period_duration')} days, "
            f"stress level={profile.get('stress_level')}, sleep hours={profile.get('sleep_hours')}, "
            f"exercise days/week={profile.get('exercise_days')}, fitness level={profile.get('fitness_level')}."
        )
        if profile.get('pss10_score') is not None:
            parts.append(
                f"Latest monthly check-in: PSS-10 perceived stress score="
                f"{profile.get('pss10_score')}/40, PSQI sleep quality score="
                f"{profile.get('psqi_global_score')}/21, hormonal-imbalance risk="
                f"{profile.get('hormonal_risk')} (assessed {profile.get('hormonal_assessment_date')})."
            )

    pred_doc = _ff(lambda: db.collection('users').document(user_id)
                   .collection('predictions').document('latest').get())
    prediction = pred_doc.to_dict() if (pred_doc is not None and pred_doc.exists) else None
    if prediction:
        parts.append(
            f"Current cycle prediction: phase={prediction.get('current_phase')}, "
            f"phase description={prediction.get('phase_description')}, "
            f"current cycle day={prediction.get('cycle_day')}, "
            f"days until next period={prediction.get('days_until_period')}, "
            f"next period={prediction.get('next_period')}, "
            f"fertile window={prediction.get('fertile_window')}, "
            f"ovulation day={prediction.get('ovulation_day')}, "
            f"cycle length={prediction.get('cycle_length')}."
        )

    logs_snap = _ff(lambda: list(
        db.collection('users').document(user_id)
        .collection('symptom_logs')
        .order_by('date', direction=firestore.Query.DESCENDING)
        .limit(5).stream()
    ), default=[], critical=critical)
    logs = [d.to_dict() for d in logs_snap]
    if logs:
        parts.append('Recent symptom logs (most recent first):')
        for log in logs:
            symptoms = ', '.join(log.get('symptoms') or []) or 'none'
            parts.append(
                f"- {log.get('date')}: mood={log.get('mood')}, flow={log.get('flow')}, "
                f"symptoms={symptoms}, notes={log.get('notes')}"
            )

    meds_snap = _ff(lambda: list(
        db.collection('users').document(user_id)
        .collection('medication_logs')
        .order_by('date', direction=firestore.Query.DESCENDING)
        .limit(5).stream()
    ), default=[], critical=critical)
    meds = [d.to_dict() for d in meds_snap]
    if meds:
        parts.append('Recent medication logs (most recent first):')
        for med in meds:
            parts.append(
                f"- {med.get('date')}: {med.get('name')} ({med.get('dosage')}), "
                f"remarks={med.get('remarks')}"
            )

    summary = '\n'.join(parts) if parts else 'No user health data is available yet.'
    return summary, prediction


def _trend_stats_from_logs(logs: list[dict], today) -> str:
    """Pure this-week-vs-last-week symptom/mood breakdown from symptom_logs.
    Split out from _weekly_trend_summary so it's testable without Firestore.
    ponytail: cycle_logs.stress_level/sleep_hours are still hardcoded
    placeholders in home_screen.dart, not real daily values, so a genuine
    stress/sleep correlation isn't computable yet — only the monthly
    PSS-10/PSQI check-in (see _build_chat_context) has real numbers. Swap
    this for a real correlation once daily values are collected.
    """
    this_week, last_week = [], []
    for log in logs:
        try:
            d = datetime.strptime(log['date'], '%Y-%m-%d').date()
        except (KeyError, ValueError, TypeError):
            continue
        days_ago = (today - d).days
        if 0 <= days_ago < 7:
            this_week.append(log)
        elif 7 <= days_ago < 14:
            last_week.append(log)

    def _describe(week):
        symptom_counts = Counter()
        moods = Counter()
        for log in week:
            symptom_counts.update(log.get('symptoms') or [])
            if log.get('mood'):
                moods[log['mood']] += 1
        top_symptoms = ', '.join(s for s, _ in symptom_counts.most_common(3)) or 'none'
        top_mood = moods.most_common(1)[0][0] if moods else 'not logged'
        return (
            f"{len(week)} days logged, {sum(symptom_counts.values())} total symptom "
            f"entries (most common: {top_symptoms}). Mood most often: {top_mood}."
        )

    return f"This week: {_describe(this_week)}\nPrevious week: {_describe(last_week)}"


def _weekly_trend_summary(user_id: str) -> str:
    # Only called by the recommendations/summary/wellness-plan cards
    # (never /chatbot), so a failed fetch is always safe to surface as 503
    # rather than silently reading as "no logs this month".
    docs = _ff(lambda: list(
        db.collection('users').document(user_id)
        .collection('symptom_logs')
        .order_by('date', direction=firestore.Query.DESCENDING)
        .limit(14).stream()
    ), default=[], critical=True)
    logs = [d.to_dict() for d in docs]
    if not logs:
        return 'No symptom logs available yet this month.'
    return _trend_stats_from_logs(logs, datetime.now().date())


# Retried once on network errors and on OpenAI status codes that are usually
# transient (rate limit / server-side hiccups). Local ML prediction (/predict)
# never calls this function, so /predict keeps working regardless of OpenAI's
# availability.
_OPENAI_MAX_ATTEMPTS = 2
_OPENAI_RETRY_STATUS = {429, 500, 502, 503, 504}
_OPENAI_RETRY_BACKOFF_SECONDS = 1.5


def _call_openai(messages: list[dict]) -> str:
    """Calls OpenAI chat completions. On any failure, raises HTTPException
    with a safe, user-friendly `detail` — the real exception/status is
    printed server-side for debugging. OPENAI_API_KEY is never included in
    any exception message, log line, or HTTP response.
    """
    if not OPENAI_API_KEY:
        print('_call_openai: OPENAI_API_KEY is not set.')
        raise HTTPException(
            status_code=503,
            detail='The AI assistant is not configured on the server right now. Please try again later.',
        )

    for attempt in range(1, _OPENAI_MAX_ATTEMPTS + 1):
        try:
            response = requests.post(
                'https://api.openai.com/v1/chat/completions',
                headers={
                    'Content-Type': 'application/json',
                    'Authorization': f'Bearer {OPENAI_API_KEY}',
                },
                json={'model': 'gpt-4o-mini', 'messages': messages},
                timeout=20,
            )
        except requests.RequestException as e:
            print(f'_call_openai: network error on attempt {attempt}/{_OPENAI_MAX_ATTEMPTS}: {e}')
            if attempt < _OPENAI_MAX_ATTEMPTS:
                time.sleep(_OPENAI_RETRY_BACKOFF_SECONDS * attempt)
                continue
            raise HTTPException(
                status_code=503,
                detail='Could not reach the AI assistant right now. Please try again in a moment.',
            )

        if response.status_code == 200:
            raw = response.json()['choices'][0]['message']['content'].strip()
            if raw.startswith('```'):
                raw = re.sub(r'^```[a-zA-Z]*\n?', '', raw)
                raw = re.sub(r'```\s*$', '', raw).strip()
            return raw

        server_detail = 'OpenAI request failed.'
        try:
            server_detail = response.json().get('error', {}).get('message', server_detail)
        except ValueError:
            pass
        print(f'_call_openai: OpenAI returned {response.status_code} on attempt '
              f'{attempt}/{_OPENAI_MAX_ATTEMPTS}: {server_detail}')

        if response.status_code in _OPENAI_RETRY_STATUS and attempt < _OPENAI_MAX_ATTEMPTS:
            time.sleep(_OPENAI_RETRY_BACKOFF_SECONDS * attempt)
            continue

        if response.status_code == 429:
            raise HTTPException(status_code=429, detail='The AI assistant is busy right now. Please try again shortly.')
        if response.status_code in (401, 403):
            raise HTTPException(status_code=503, detail='The AI assistant is not configured correctly on the server.')
        raise HTTPException(status_code=503, detail='The AI assistant is temporarily unavailable. Please try again later.')

    # Unreachable (the loop always returns or raises), kept for clarity.
    raise HTTPException(status_code=503, detail='The AI assistant is temporarily unavailable. Please try again later.')


AI_DISCLAIMER = (
    'Always remind users to consult a healthcare professional for '
    'personalised medical advice.'
)

MARKDOWN_INSTRUCTION = (
    'Format the response as Markdown: **bold** key terms and use a '
    '"- " bullet list for list items.'
)

RECOMMENDATIONS_SYSTEM_PROMPT = (
    'You are Luna, a menstrual and wellness health assistant. Using the '
    "user's health data below, write 3-5 short, specific, personalized "
    'lifestyle and wellness recommendations covering sleep, stress, exercise, '
    f'and nutrition as a bullet list. Be concrete, not generic. {MARKDOWN_INSTRUCTION} {AI_DISCLAIMER}'
)

WEEKLY_SUMMARY_SYSTEM_PROMPT = (
    'You are Luna, a menstrual and wellness health assistant. Using the '
    "user's health data and this-week-vs-last-week trends below, write a "
    'short, easy-to-understand weekly summary (3-5 sentences) highlighting '
    f'improvements, concerns, and notable changes. {MARKDOWN_INSTRUCTION} {AI_DISCLAIMER}'
)

WELLNESS_PLAN_SYSTEM_PROMPT = (
    'You are Luna, a menstrual and wellness health assistant. Using the '
    "user's health data and recent trends below, generate a practical daily "
    'wellness plan (sleep, exercise, relaxation, nutrition) as a short '
    'bullet list tailored to their current cycle phase and stress/sleep '
    f'levels. {MARKDOWN_INSTRUCTION} {AI_DISCLAIMER}'
)

class UserIdRequest(BaseModel):
    user_id: str

@app.post('/ai/recommendations')
def ai_recommendations(req: UserIdRequest):
    context_summary, _ = _build_chat_context(req.user_id, critical=True)
    messages = [{'role': 'system', 'content': f'{RECOMMENDATIONS_SYSTEM_PROMPT}\n\n{context_summary}'}]
    return {'text': _call_openai(messages)}

@app.post('/ai/weekly-summary')
def ai_weekly_summary(req: UserIdRequest):
    context_summary, _ = _build_chat_context(req.user_id, critical=True)
    trend_summary = _weekly_trend_summary(req.user_id)
    messages = [{'role': 'system', 'content': f'{WEEKLY_SUMMARY_SYSTEM_PROMPT}\n\n{context_summary}\n\n{trend_summary}'}]
    return {'text': _call_openai(messages)}

@app.post('/ai/wellness-plan')
def ai_wellness_plan(req: UserIdRequest):
    context_summary, _ = _build_chat_context(req.user_id, critical=True)
    trend_summary = _weekly_trend_summary(req.user_id)
    messages = [{'role': 'system', 'content': f'{WELLNESS_PLAN_SYSTEM_PROMPT}\n\n{context_summary}\n\n{trend_summary}'}]
    return {'text': _call_openai(messages)}

@app.post('/chatbot')
def chatbot(req: ChatRequest):
    context_summary, prediction = _build_chat_context(req.user_id)

    messages = [{'role': 'system', 'content': f'{CHAT_SYSTEM_PROMPT}\n\n{context_summary}'}]
    messages += [{'role': m.role, 'content': m.content} for m in req.history]
    messages.append({'role': 'user', 'content': req.message})

    raw = _call_openai(messages)

    reply: dict
    try:
        parsed = json.loads(raw)
        if (
            isinstance(parsed, dict)
            and parsed.get('type') == 'infographic'
            and parsed.get('chart') in KNOWN_CHARTS
            and isinstance(parsed.get('data'), dict)
        ):
            reply = {'type': 'infographic', 'chart': parsed['chart'], 'data': parsed['data']}
        else:
            reply = {'type': 'text', 'text': raw}
    except (json.JSONDecodeError, TypeError):
        reply = {'type': 'text', 'text': raw}

    phase = (prediction or {}).get('current_phase', '')
    cycle_day = (prediction or {}).get('cycle_day')
    reply_log_text = (
        raw if reply['type'] == 'text'
        else f"Displayed a {reply['chart']} infographic to the user."
    )

    _ff(lambda: db.collection('users').document(req.user_id)
        .collection('chat_logs').add({
            'user_id':   req.user_id,
            'message':   req.message,
            'reply':     reply_log_text,
            'phase':     phase,
            'cycle_day': cycle_day,
            'timestamp': datetime.now().isoformat(),
        }))

    reply['phase'] = phase
    reply['cycleDay'] = cycle_day
    return reply
