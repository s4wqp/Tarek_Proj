import requests
import json

base_url = 'http://161.35.51.188:5001/api'

# 1. Login
login_res = requests.post(f"{base_url}/auth/login", json={"uname": "ts2025", "password": "123456"})
token = login_res.json().get('token') or login_res.json().get('accessToken')
headers = {"Authorization": f"Bearer {token}"}

# 2. Get trips my
res = requests.get(f"{base_url}/trips/my", headers=headers)
with open("out.txt", "w", encoding="utf-8") as f:
    f.write(res.text)

# Also let's try creating a trip
payload = {
    'cat_id': 201,
    'start_stop_id': 1,
    'end_stop_id': 2,
    'trip_title': 'Script Trip',
    'seats_available': 4,
    'measurement_type': 1,
    'total_distance': 10,
    'price_per_seat_mu': 10,
    'is_active': True,
    'is_recurring': False,
    'schedule': {
        'trip_time': '07:30:00',
        'days_of_week': ['Mon'],
        'start_date': '2026-04-15',
        'end_date': '2026-05-15',
    },
    'intermediate_stops': [3, 4],
    'stops': [3, 4]
}

create_res = requests.post(f"{base_url}/trips", json=payload, headers=headers)
with open("out_create.txt", "w", encoding="utf-8") as f:
    f.write(str(create_res.status_code) + "\n")
    f.write(create_res.text)

if create_res.status_code in [200, 201]:
    data = create_res.json()
    trip_id = data.get('trip_id') or data.get('id')
    if trip_id:
        add_res = requests.post(f"{base_url}/trips/{trip_id}/stops", json={'stop_id': 3, 'stop_order': 1}, headers=headers)
        with open("out_add.txt", "w", encoding="utf-8") as f:
            f.write(add_res.text)
        
        route_res = requests.get(f"{base_url}/trips/{trip_id}/route", headers=headers)
        with open("out_route.txt", "w", encoding="utf-8") as f:
            f.write(route_res.text)
