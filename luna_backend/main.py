from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from datetime import datetime, timedelta
import joblib
import numpy as np
import firebase_admin
from firebase_admin import credentials, firestore
import os

cred = credentials.Certificate(
    'firebase_config/serviceAccountKey.json')
firebase_admin.initialize_app(cred)
db = firestore.client()

model = joblib.load('model/cycle_model.pkl')

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
    avg_cycle_length: float
    avg_period_duration: float
    age: int
    stress_level: int
    sleep_hours: float
    exercise_days: int
    last_period_start: str

class ChatRequest(BaseModel):
    user_id: str
    message: str
    current_phase:str
    cycle_day: int

def get_phase(cycle_day: int, cycle_length: int) -> dict:
    if cycle_day <= 5:
        return {'phase': 'Menstrual',   'description': 'Your period is active. Rest and stay hydrated.'}
    elif cycle_day <= 13:
        return {'phase': 'Follicular',  'description': 'Energy rising. Good time for strength training.'}
    elif cycle_day <= 16:
        return {'phase': 'Ovulation',   'description': 'Peak fertility window. Energy is at its highest.'}
    else:
        return {'phase': 'Luteal',      'description': 'Progesterone rising. Prefer low-impact exercise.'}
    
@app.get('/')
def root():
    return {'message': 'Luna Health API is running'}

@app.post('/user/create')
def create_user(user: UserProfile):
    db.collection('users').document(user.user_id).set({
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
    })
    return {'status': 'User created', 'user_id': user.user_id}

@app.get('/user/{user_id}')
def get_user(user_id: str):
    doc = db.collection('users').document(user_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail='User not found')
    return doc.to_dict()

@app.post('/cycle/log')
def log_cycle(log: CycleLog):
    start = datetime.strptime(log.period_start, '%Y-%m-%d')
    end   = datetime.strptime(log.period_end,   '%Y-%m-%d')
    duration = (end - start).days + 1

    db.collection('cycle_logs').add({
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
    })
    return {'status': 'Cycle logged', 'duration': duration}

@app.get('/cycle/history/{user_id}')
def get_history(user_id: str):
    try:
        docs = (
            db.collection('cycle_logs')
            .where('user_id', '==', user_id)
            .order_by('period_start', direction=firestore.Query.DESCENDING)
            .stream()
        )

        return [d.to_dict() for d in docs]

    except Exception as e:
        print("Firestore error:", e)
        raise HTTPException(status_code=500, detail=str(e))


@app.post('/predict')
def predict_cycle(req: PredictRequest):
    features = np.array([[
        req.avg_cycle_length,
        req.avg_period_duration,
        req.age,
        req.stress_level,
        req.sleep_hours,
        req.exercise_days,
    ]])

    predicted_cycle_length = round(float(model.predict(features)[0]), 1)

    last_start = datetime.strptime(req.last_period_start, '%Y-%m-%d')
    next_period_start = last_start + timedelta(days=int(predicted_cycle_length))
    next_period_end   = next_period_start + timedelta(days=int(req.avg_period_duration))

    ovulation_day   = last_start + timedelta(days=int(predicted_cycle_length) - 14)
    fertile_start   = ovulation_day - timedelta(days=5)
    fertile_end     = ovulation_day + timedelta(days=1)

    today       = datetime.now()
    days_passed = (today - last_start).days
    cycle_day = (days_passed % int(predicted_cycle_length)) + 1
    phase_info  = get_phase(cycle_day, int(predicted_cycle_length))

    
    db.collection('users').document(req.user_id)\
    .collection('predictions').add({
    'predicted_cycle_length': predicted_cycle_length,
    'next_period_start': next_period_start.strftime('%Y-%m-%d'),
    'next_period_end': next_period_end.strftime('%Y-%m-%d'),
    'ovulation_day': ovulation_day.strftime('%Y-%m-%d'),
    'fertile_start': fertile_start.strftime('%Y-%m-%d'),
    'fertile_end': fertile_end.strftime('%Y-%m-%d'),
    'current_phase': phase_info['phase'],
    'cycle_day': cycle_day,
    'predicted_at': datetime.now().isoformat(),
})

    return {
        'predicted_cycle_length': predicted_cycle_length,
        'next_period_start':      next_period_start.strftime('%d %b %Y'),
        'next_period_end':        next_period_end.strftime('%d %b %Y'),
        'ovulation_day':          ovulation_day.strftime('%d %b %Y'),
        'fertile_window':         f"{fertile_start.strftime('%d %b')} – {fertile_end.strftime('%d %b %Y')}",
        'current_phase':          phase_info['phase'],
        'phase_description':      phase_info['description'],
        'cycle_day':              cycle_day,
    }

@app.post('/chatbot')
def chatbot(req: ChatRequest):
    msg   = req.message.lower()
    phase = req.current_phase
    day   = req.cycle_day

   
    if any(w in msg for w in ['late', 'delay', 'overdue']):
        reply = (f'Your period may be late due to stress, sleep changes '
                 f'or hormonal shifts. You are currently on cycle day {day}. '
                 f'If it is more than 7 days late, consider consulting a doctor.')

    elif any(w in msg for w in ['cramp', 'pain', 'hurt']):
        reply = ('For cramps, try gentle yoga, a warm compress, or light '
                 'walking. Ibuprofen can also help. If pain is severe, '
                 'please see a healthcare professional.')

    elif any(w in msg for w in ['fertile', 'ovulat', 'pregnant', 'conceive']):
        reply = ('Your fertile window is typically 5 days before ovulation '
                 'and 1 day after. Ovulation usually occurs around day 14 '
                 'of your cycle. Check your prediction card for exact dates.')

    elif any(w in msg for w in ['exercise', 'workout', 'gym', 'sport']):
        if phase == 'Luteal':
            reply = ('During your luteal phase, low-impact exercises like '
                     'yoga, walking and swimming are best. Avoid high-intensity '
                     'workouts as recovery is slower.')
        elif phase == 'Follicular':
            reply = ('Great time to exercise! During the follicular phase '
                     'your energy is rising — strength training and cardio '
                     'are well-suited.')
        elif phase == 'Ovulation':
            reply = ('You are at peak energy during ovulation. HIIT, '
                     'running and strength training all work well now.')
        else:
            reply = ('During menstruation, gentle movement like yoga and '
                     'walking can ease cramps. Rest as needed.')

    elif any(w in msg for w in ['mood', 'sad', 'anxious', 'irritable', 'emotional']):
        reply = (f'Mood changes during the {phase} phase are very normal due '
                 f'to hormonal fluctuations. Try light exercise, journalling '
                 f'and adequate sleep to help regulate mood.')

    elif any(w in msg for w in ['phase', 'stage', 'cycle day']):
        reply = (f'You are currently in the {phase} phase on cycle day {day}. '
                 f'{get_phase(day, 28)["description"]}')

    elif any(w in msg for w in ['bloat', 'swollen', 'puff']):
        reply = ('Bloating is common in the luteal phase due to progesterone. '
                 'Reduce salt intake, stay hydrated, and try light yoga to ease it.')

    else:
        reply = ('I\'m here to help with your cycle and wellness questions. '
                 'You can ask me about your phase, symptoms, exercise, '
                 'fertility or mood. For medical concerns please consult a doctor.')

    
    db.collection('users').document(req.user_id)\
    .collection('chat_logs').add({
        'user_id':   req.user_id,
        'message':   req.message,
        'reply':     reply,
        'phase':     phase,
        'cycle_day': day,
        'timestamp': datetime.now().isoformat(),
    })

    return {'reply': reply, 'phase': phase, 'cycle_day': day}
