$response = Invoke-RestMethod -Uri 'http://161.35.51.188:5001/api/auth/login' -Method Post -Body '{"uname":"ts2025","password":"123456"}' -ContentType 'application/json'
$token = $response.token
if ([string]::IsNullOrEmpty($token)) {
    $token = $response.accessToken
}
$user = Invoke-RestMethod -Uri 'http://161.35.51.188:5001/api/users/30' -Headers @{Authorization="Bearer $token"}
$user | ConvertTo-Json -Depth 10 | Out-File -FilePath d:\tarek_proj\api_output_detail.json -Encoding utf8
