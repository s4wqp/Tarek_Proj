$response = Invoke-RestMethod -Uri 'http://161.35.51.188:5001/api/auth/login' -Method Post -Body '{"uname":"ts2025","password":"123456"}' -ContentType 'application/json'
$token = $response.token
if ([string]::IsNullOrEmpty($token)) {
    $token = $response.accessToken
}
$usersResponse = Invoke-RestMethod -Uri 'http://161.35.51.188:5001/api/users' -Headers @{Authorization="Bearer $token"}
# Find yousef@gmail.com
$user = $usersResponse.data | Where-Object { $_.user_email -eq 'yousef@gmail.com' -or $_.email -eq 'yousef@gmail.com' -or $_.user_name -eq 'yousef' }
$user | ConvertTo-Json -Depth 10 | Out-File -FilePath d:\tarek_proj\api_output.json -Encoding utf8
