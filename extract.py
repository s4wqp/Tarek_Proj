import json
import urllib.request

# Login to get token
login_url = "http://161.35.51.188:5001/api/auth/login"
login_data = json.dumps({"uname": "ts2025", "password": "123456"}).encode("utf-8")
req = urllib.request.Request(login_url, data=login_data, headers={'Content-Type': 'application/json'})
response = urllib.request.urlopen(req)
token_data = json.loads(response.read())
token = token_data.get("token", token_data.get("accessToken", ""))

# Fetch users
users_url = "http://161.35.51.188:5001/api/users"
req2 = urllib.request.Request(users_url, headers={'Authorization': f'Bearer {token}'})
res2 = urllib.request.urlopen(req2)
users_data = json.loads(res2.read())

users = users_data.get("data", users_data)
for u in users:
    email = str(u.get('email') or u.get('user_email') or '')
    if 'redhode' in email.lower() or 'fakeee' in email.lower() or 'yousef' in email.lower():
        print("==========")
        print("Email:", email)
        print("Name keys:")
        for k in ['user_name', 'uname', 'user_f_name', 'user_l_name', 'firstName', 'lastName', 'name']:
            if k in u:
                print(f"  {k}: {u[k]}")
