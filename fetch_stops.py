import urllib.request
import json
import ssl

token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6MzAsInVuYW1lIjoieW91c2VmIiwicm9sZSI6MjAxLCJpYXQiOjE3NzYwODkzNDEsImV4cCI6MTc3NjE3NTc0MX0.gOS0ykALJJLXZMZCLlYD0h6ZqTGn3t1VLzIavYnfrG0"

req = urllib.request.Request("https://api.aidme.online/api/stops")
req.add_header("Authorization", f"Bearer {token}")
req.add_header("Accept", "application/json")

# Bypass ssl verification for test
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

try:
    with urllib.request.urlopen(req, context=ctx) as response:
        data = json.loads(response.read().decode())
        with open('stops.json', 'w') as f:
            json.dump(data, f, indent=2)
except Exception as e:
    with open('stops.json', 'w') as f:
        f.write(str(e))
