import pandas as pd
import numpy as np
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error 
import joblib

np.random.seed(42)
n = 500

data = pd.DataFrame({
    'avg_cycle_length':         np.random.normal(28,3,n).clip(21,40),
    'avg_period_duration':      np.random.normal(5,1,n).clip(2,8),
    'age':                      np.random.randint(15,50,n),
    'stress_level':             np.random.randint(1,5,n),       #min:1 high:5
    'sleep_hours':              np.random.normal(7,1,n).clip(4,10),
    'exercise_days':            np.random.randint(0,7,n),  

})

data['next_cycle_length'] = (
    data['avg_cycle_length']
    + np.random.normal(0,1.5,n) 
    + (data['stress_level'] - 3) * 0.8 
    - (data['exercise_days'] - 3) * 0.3
    ).clip(21,40)

X = data.drop('next_cycle_length', axis = 1)
y = data['next_cycle_length']

X_train, X_test, y_train, y_test = train_test_split( X, y, test_size = 0.2, random_state = 42)

model = GradientBoostingRegressor( 
    n_estimators = 200,
    learning_rate = 0.05,
    max_depth = 4,
    random_state = 42
)

model.fit(X_train,y_train)
pred = model.predict(X_test)
mean = mean_absolute_error(y_test, pred)
print(f'Model trained. Mean: {mean:.2f} days')
joblib.dump(model, 'cycle_model.pkl')
print('Model saved to cycle_model.pkl')