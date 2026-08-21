"""Evaluates the two production models against a held-out test set.

Does NOT retrain or modify cycle_model.pkl / cycle_length_model.pkl — it loads
the already-trained bundles with joblib and scores them, reusing the exact
preprocessing functions from train_model.py so the held-out split matches
what training actually used (same random_state=42, test_size=0.2).

    cycle_model.pkl        4-class phase classifier (Menstrual/Follicular/
                            Fertility/Luteal) -> accuracy, precision, recall,
                            macro F1, confusion matrix. MAE/RMSE/R2 do not
                            apply to a categorical classifier, so they are
                            not reported for this model.

    cycle_length_model.pkl regressor for days-until-next-period. main.py's
                            /predict adds this prediction (clamped to
                            15-60 days, same as production) to the user's
                            last period start date to get the next-period
                            date, so a date-prediction's day-level error is
                            identical to the cycle-length error in days.
                            Reported here as "next_period_date_prediction"
                            using the same test cycles for that framing.
                            Evaluated with MAE, RMSE, R2, +/-1 day and +/-3
                            day accuracy, and against a naive "always guess
                            28 days" baseline.

Run from anywhere:
    python model/evaluate_models.py

Outputs:
    evaluation/results/ml_results.json
    evaluation/results/ml_results.csv
"""
import csv
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score, precision_recall_fscore_support, confusion_matrix,
    mean_absolute_error, mean_squared_error, r2_score,
)
from sklearn.model_selection import train_test_split

MODEL_DIR = Path(__file__).resolve().parent
BACKEND_DIR = MODEL_DIR.parent
RESULTS_DIR = BACKEND_DIR / 'evaluation' / 'results'

sys.path.insert(0, str(MODEL_DIR))
from train_model import (  # noqa: E402
    FEATURE_COLUMNS, LIKERT_COLUMNS, LIKERT_SCALE, FLOW_VOLUME_SCALE,
    encode_scale, add_cycle_day, build_cycle_length_dataset,
)

RANDOM_STATE = 42
TEST_SIZE = 0.2
NAIVE_CYCLE_LENGTH_DAYS = 28  # baseline: "every user has a 28-day cycle"


def load_preprocessed_data():
    """Rebuilds the exact dataframe train_model.py trains on, using the
    saved encoders (not freshly-fit ones) so categorical codes match the
    production model exactly."""
    df = pd.read_csv(MODEL_DIR / 'data' / 'hormones_and_selfreport.csv')
    df['flow_volume'] = encode_scale(df['flow_volume'], FLOW_VOLUME_SCALE)
    for col in LIKERT_COLUMNS:
        df[col] = encode_scale(df[col], LIKERT_SCALE)
    df = add_cycle_day(df)
    df = df.dropna(subset=['phase', *FEATURE_COLUMNS])
    return df


def evaluate_phase_classifier(df):
    bundle = joblib.load(MODEL_DIR / 'cycle_model.pkl')
    model = bundle['model']
    label_encoder = bundle['label_encoder']
    flow_color_encoder = bundle['flow_color_encoder']
    feature_order = bundle['feature_order']

    df = df.copy()
    df['flow_color'] = flow_color_encoder.transform(df['flow_color'])

    X = df[feature_order]
    y = label_encoder.transform(df['phase'])

    _, X_test, _, y_test = train_test_split(
        X, y, test_size=TEST_SIZE, random_state=RANDOM_STATE, stratify=y
    )

    pred = model.predict(X_test)
    classes = label_encoder.classes_.tolist()
    precision, recall, f1, support = precision_recall_fscore_support(
        y_test, pred, labels=range(len(classes)), zero_division=0
    )
    cm = confusion_matrix(y_test, pred, labels=range(len(classes)))

    return {
        'model_file': 'cycle_model.pkl',
        'task': '4-class cycle-phase classification (Menstrual/Follicular/Fertility/Luteal)',
        'test_set_size': int(len(y_test)),
        'accuracy': round(float(accuracy_score(y_test, pred)), 4),
        'macro_precision': round(float(precision.mean()), 4),
        'macro_recall': round(float(recall.mean()), 4),
        'macro_f1': round(float(f1.mean()), 4),
        'per_class': [
            {
                'class': classes[i],
                'precision': round(float(precision[i]), 4),
                'recall': round(float(recall[i]), 4),
                'f1': round(float(f1[i]), 4),
                'support': int(support[i]),
            }
            for i in range(len(classes))
        ],
        'confusion_matrix': {
            'labels': classes,
            'matrix': cm.tolist(),
        },
        'note': (
            'MAE/RMSE/R2/+-day-accuracy do not apply to a categorical classifier; '
            'see cycle_length_regressor and next_period_date_prediction below for '
            'the day-based regression metrics.'
        ),
    }


def _day_error_metrics(y_true, y_pred_raw):
    """Shared regression metrics for both the length model and the naive baseline.
    Predictions are rounded to whole days, matching how main.py's /predict
    endpoint actually rounds/clamps the model output before using it."""
    y_pred = np.clip(np.round(y_pred_raw), 15, 60)
    errors = np.abs(y_true - y_pred)
    return {
        'mae_days': round(float(mean_absolute_error(y_true, y_pred)), 3),
        'rmse_days': round(float(np.sqrt(mean_squared_error(y_true, y_pred))), 3),
        'r2': round(float(r2_score(y_true, y_pred)), 4),
        'within_1_day_pct': round(float((errors <= 1).mean() * 100), 2),
        'within_3_day_pct': round(float((errors <= 3).mean() * 100), 2),
    }


def evaluate_length_regressor(df):
    bundle = joblib.load(MODEL_DIR / 'cycle_length_model.pkl')
    length_model = bundle['model']
    feature_order = bundle['feature_order']

    subject_info = pd.read_csv(MODEL_DIR / 'data' / 'subject-info.csv')
    length_df = build_cycle_length_dataset(df, subject_info)

    X_len = length_df[feature_order]
    y_len = length_df['cycle_length']

    _, X_len_test, _, y_len_test = train_test_split(
        X_len, y_len, test_size=TEST_SIZE, random_state=RANDOM_STATE
    )

    y_true = y_len_test.to_numpy()
    model_pred_raw = length_model.predict(X_len_test)
    baseline_pred_raw = np.full_like(y_true, NAIVE_CYCLE_LENGTH_DAYS, dtype=float)

    model_metrics = _day_error_metrics(y_true, model_pred_raw)
    baseline_metrics = _day_error_metrics(y_true, baseline_pred_raw)

    cycle_length_regressor = {
        'model_file': 'cycle_length_model.pkl',
        'task': 'predict days until next period (cycle length in days)',
        'test_set_size': int(len(y_len_test)),
        **model_metrics,
        'baseline': {
            'description': f'naive baseline: always predict {NAIVE_CYCLE_LENGTH_DAYS} days',
            **baseline_metrics,
        },
        'beats_baseline': model_metrics['mae_days'] < baseline_metrics['mae_days'],
    }

    # Same held-out cycles, framed as the app actually presents them: a next
    # period *date* = last_period_start + predicted_cycle_length (main.py
    # /predict). The day-level error is mathematically identical to the
    # cycle-length error above; this section restates it in that framing
    # per the requested report structure.
    next_period_date_prediction = {
        'derivation': (
            'next_period_date = last_period_start + predicted_cycle_length, '
            'exactly as computed in main.py /predict. Day-level error is '
            'therefore identical to cycle_length_regressor above.'
        ),
        'test_set_size': int(len(y_len_test)),
        **model_metrics,
        'baseline': {
            'description': f'naive baseline: assume next period is always {NAIVE_CYCLE_LENGTH_DAYS} days after the last one',
            **baseline_metrics,
        },
        'beats_baseline': model_metrics['mae_days'] < baseline_metrics['mae_days'],
    }

    return cycle_length_regressor, next_period_date_prediction


def flatten_to_rows(results):
    rows = []

    pc = results['phase_classifier']
    rows.append(['phase_classifier', 'test_set_size', pc['test_set_size']])
    rows.append(['phase_classifier', 'accuracy', pc['accuracy']])
    rows.append(['phase_classifier', 'macro_precision', pc['macro_precision']])
    rows.append(['phase_classifier', 'macro_recall', pc['macro_recall']])
    rows.append(['phase_classifier', 'macro_f1', pc['macro_f1']])
    for cls in pc['per_class']:
        for metric in ('precision', 'recall', 'f1', 'support'):
            rows.append([f"phase_classifier[{cls['class']}]", metric, cls[metric]])

    for section_name in ('cycle_length_regressor', 'next_period_date_prediction'):
        sec = results[section_name]
        for metric in ('test_set_size', 'mae_days', 'rmse_days', 'r2', 'within_1_day_pct', 'within_3_day_pct'):
            rows.append([section_name, metric, sec[metric]])
        rows.append([section_name, 'beats_28day_baseline', sec['beats_baseline']])
        for metric in ('mae_days', 'rmse_days', 'r2', 'within_1_day_pct', 'within_3_day_pct'):
            rows.append([f'{section_name}[baseline_28day]', metric, sec['baseline'][metric]])

    return rows


def main():
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    df = load_preprocessed_data()
    phase_classifier = evaluate_phase_classifier(df)
    cycle_length_regressor, next_period_date_prediction = evaluate_length_regressor(df)

    results = {
        'generated_at': datetime.now(timezone.utc).isoformat(),
        'random_state': RANDOM_STATE,
        'test_size': TEST_SIZE,
        'phase_classifier': phase_classifier,
        'cycle_length_regressor': cycle_length_regressor,
        'next_period_date_prediction': next_period_date_prediction,
    }

    json_path = RESULTS_DIR / 'ml_results.json'
    json_path.write_text(json.dumps(results, indent=2), encoding='utf-8')

    csv_path = RESULTS_DIR / 'ml_results.csv'
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(['section', 'metric', 'value'])
        writer.writerows(flatten_to_rows(results))

    print(f'Phase classifier: accuracy={phase_classifier["accuracy"]:.2%}, macro_f1={phase_classifier["macro_f1"]:.4f} (n={phase_classifier["test_set_size"]})')
    print(
        f'Cycle-length model: MAE={cycle_length_regressor["mae_days"]}d, '
        f'RMSE={cycle_length_regressor["rmse_days"]}d, R2={cycle_length_regressor["r2"]}, '
        f'+/-1d={cycle_length_regressor["within_1_day_pct"]}%, +/-3d={cycle_length_regressor["within_3_day_pct"]}% '
        f'(n={cycle_length_regressor["test_set_size"]}) vs 28-day baseline MAE='
        f'{cycle_length_regressor["baseline"]["mae_days"]}d -> beats baseline: {cycle_length_regressor["beats_baseline"]}'
    )
    print(f'Results written to {json_path} and {csv_path}')


if __name__ == '__main__':
    main()
