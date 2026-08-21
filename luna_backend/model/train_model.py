import pandas as pd
import numpy as np
from sklearn.ensemble import GradientBoostingClassifier, GradientBoostingRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score, mean_absolute_error
from sklearn.preprocessing import LabelEncoder
import joblib

# Real self-reported daily data from the mcPHASES dataset (Mira device + symptom surveys).
# Hormone assay columns (lh, estrogen, pdg) are excluded: the app has no way to measure
# those from a user, so training on them would make the model rely on data it'll never get.
FEATURE_COLUMNS = [
    'cycle_day', 'flow_volume', 'flow_color', 'appetite', 'exerciselevel',
    'headaches', 'cramps', 'sorebreasts', 'fatigue', 'sleepissue',
    'moodswing', 'stress', 'foodcravings', 'indigestion', 'bloating',
]

# Survey responses are Likert text labels (a few rows have raw digit artifacts
# instead), so map them to an ordinal 0-5 scale rather than one-hot encoding.
LIKERT_SCALE = {
    'not at all': 0, 'very low/little': 1, 'very low': 1,
    'low': 2, 'moderate': 3, 'high': 4, 'very high': 5,
}
FLOW_VOLUME_SCALE = {
    'not at all': 0, 'spotting / very light': 1, 'light': 2,
    'somewhat light': 3, 'moderate': 4, 'somewhat heavy': 5,
    'heavy': 6, 'very heavy': 7,
}
LIKERT_COLUMNS = [
    'appetite', 'exerciselevel', 'headaches', 'cramps', 'sorebreasts',
    'fatigue', 'sleepissue', 'moodswing', 'stress', 'foodcravings',
    'indigestion', 'bloating',
]
MIN_BLEEDING_LEVEL = 2   # 'Light' or heavier on FLOW_VOLUME_SCALE, to exclude spotting
MIN_GAP_DAYS = 10        # minimum days between two period starts, to exclude spotting mid-cycle


def encode_scale(series, scale):
    def convert(v):
        if pd.isna(v):
            return np.nan
        s = str(v).strip()
        return int(s) if s.lstrip('-').isdigit() else scale[s.lower()]
    return series.map(convert)


def add_cycle_day(df):
    """Derive each row's day-within-cycle from its own flow_volume history (per participant),
    without touching the `phase` label — mirrors the 'last period date' input a real user
    would supply, but computed from data instead."""
    df = df.sort_values(['id', 'day_in_study']).reset_index(drop=True)
    cycle_day = np.full(len(df), np.nan)
    for _, g in df.groupby('id'):
        flow = g['flow_volume'].fillna(0).to_numpy()
        day = g['day_in_study'].to_numpy()
        last_start = None
        for i, idx in enumerate(g.index):
            is_bleeding = flow[i] >= MIN_BLEEDING_LEVEL
            new_period = is_bleeding and (i == 0 or flow[i - 1] < MIN_BLEEDING_LEVEL) \
                and (last_start is None or day[i] - last_start >= MIN_GAP_DAYS)
            if new_period:
                last_start = day[i]
            if last_start is not None:
                cycle_day[idx] = day[i] - last_start + 1
    df['cycle_day'] = cycle_day
    return df


# ── Next-cycle-length regressor feature set ──────────────────────────
# Predicts how many days until the next period, from age + this cycle's
# average stress/sleep/symptom severity. Weight and medication are NOT
# included: the dataset has no such columns, so training on them would be
# fabricating a signal the model never actually saw.
LENGTH_FEATURE_COLUMNS = [
    'age', 'stress', 'sleepissue', 'headaches', 'cramps', 'sorebreasts',
    'fatigue', 'moodswing', 'foodcravings', 'indigestion', 'bloating',
]
MIN_CYCLE_LENGTH = 15   # days; shorter gaps are almost certainly missed logging
MAX_CYCLE_LENGTH = 60


def build_cycle_length_dataset(daily_df, subject_info):
    daily_df = daily_df.merge(
        subject_info[['id', 'birth_year']], on='id', how='left'
    )
    daily_df['age'] = daily_df['study_interval'] - daily_df['birth_year']

    rows = []
    for _, g in daily_df.groupby('id'):
        g = g.sort_values('day_in_study')
        starts = g.loc[g['cycle_day'] == 1, 'day_in_study'].tolist()
        for k in range(len(starts) - 1):
            cycle_length = starts[k + 1] - starts[k]
            if not (MIN_CYCLE_LENGTH <= cycle_length <= MAX_CYCLE_LENGTH):
                continue
            span = g[(g['day_in_study'] >= starts[k]) & (g['day_in_study'] < starts[k + 1])]
            means = span[LENGTH_FEATURE_COLUMNS].mean()
            if means.isna().any():
                continue
            rows.append({**means.to_dict(), 'cycle_length': cycle_length})
    return pd.DataFrame(rows)


def main():
    df = pd.read_csv('data/hormones_and_selfreport.csv')

    df['flow_volume'] = encode_scale(df['flow_volume'], FLOW_VOLUME_SCALE)
    for col in LIKERT_COLUMNS:
        df[col] = encode_scale(df[col], LIKERT_SCALE)

    df = add_cycle_day(df)
    df = df.dropna(subset=['phase', *FEATURE_COLUMNS])

    flow_color_encoder = LabelEncoder().fit(df['flow_color'])
    df['flow_color'] = flow_color_encoder.transform(df['flow_color'])

    X = df[FEATURE_COLUMNS]
    label_encoder = LabelEncoder()
    y = label_encoder.fit_transform(df['phase'])

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    model = GradientBoostingClassifier(
        n_estimators=200,
        learning_rate=0.05,
        max_depth=4,
        random_state=42,
    )

    model.fit(X_train, y_train)
    pred = model.predict(X_test)
    acc = accuracy_score(y_test, pred)
    print(f'Model trained on {len(df)} real records. Accuracy: {acc:.2%}')
    print(classification_report(y_test, pred, target_names=label_encoder.classes_))

    joblib.dump({
        'model': model,
        'label_encoder': label_encoder,
        'flow_color_encoder': flow_color_encoder,
        'feature_order': FEATURE_COLUMNS,
    }, 'cycle_model.pkl')
    print('Model saved to cycle_model.pkl')

    subject_info = pd.read_csv('data/subject-info.csv')
    length_df = build_cycle_length_dataset(df, subject_info)

    X_len = length_df[LENGTH_FEATURE_COLUMNS]
    y_len = length_df['cycle_length']

    X_len_train, X_len_test, y_len_train, y_len_test = train_test_split(
        X_len, y_len, test_size=0.2, random_state=42
    )

    length_model = GradientBoostingRegressor(
        n_estimators=200,
        learning_rate=0.05,
        max_depth=3,
        random_state=42,
    )
    length_model.fit(X_len_train, y_len_train)
    len_pred = length_model.predict(X_len_test)
    mae = mean_absolute_error(y_len_test, len_pred)
    print(f'Cycle-length model trained on {len(length_df)} cycles. MAE: {mae:.2f} days')

    joblib.dump({
        'model': length_model,
        'feature_order': LENGTH_FEATURE_COLUMNS,
    }, 'cycle_length_model.pkl')
    print('Model saved to cycle_length_model.pkl')


if __name__ == '__main__':
    main()
