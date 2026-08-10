from datetime import date, timedelta
from main import _trend_stats_from_logs


def test_trend_stats_counts_and_buckets_by_week():
    today = date(2026, 8, 8)
    logs = [
        {'date': (today - timedelta(days=1)).isoformat(), 'symptoms': ['cramps', 'fatigue'], 'mood': 'Tired'},
        {'date': (today - timedelta(days=2)).isoformat(), 'symptoms': ['cramps'], 'mood': 'Tired'},
        {'date': (today - timedelta(days=10)).isoformat(), 'symptoms': ['headache'], 'mood': 'Okay'},
        {'date': 'not-a-date', 'symptoms': ['ignored']},
    ]
    summary = _trend_stats_from_logs(logs, today)
    this_part, last_part = summary.split('Previous week')

    assert 'This week: 2 days logged, 3 total symptom entries' in this_part
    assert 'cramps' in this_part
    assert 'Mood most often: Tired' in this_part

    assert '1 days logged, 1 total symptom entries' in last_part
    assert 'headache' in last_part
    assert 'Mood most often: Okay' in last_part


if __name__ == '__main__':
    test_trend_stats_counts_and_buckets_by_week()
    print('ok')
