# LocalFlow HTTP API Protocol v1

## Discovery

- Service type: `_localflow._tcp`
- Default port: `8080`
- TXT record: `name` (server display name), `version` (protocol version)

## Endpoints

### Health Check
```
GET /api/health
Response: {"status": "ok", "name": "MacBook Name"}
```

### Initiate Pairing
```
POST /api/pair
Content-Type: application/json
Body: {"deviceId": "uuid", "deviceName": "Pixel 8"}
Response: {"status": "pending", "message": "Enter the code shown on your Mac"}
```

### Confirm Pairing
```
POST /api/pair/confirm
Content-Type: application/json
Body: {"deviceId": "uuid", "code": "847291"}
Response: {"token": "auth-uuid", "serverName": "MacBook Name"}
```

### Recording State Sync
```
POST /api/recording
Authorization: Bearer {token}
Content-Type: application/json
Body: {"recording": true}
Response: {"status": "ok"}
```
Phone calls this when it starts (`true`) or stops (`false`) recording. Mac UI reflects the phone's recording state on its record button.

### Status (Phone Polling)
```
GET /api/status
Authorization: Bearer {token}
Response: {"stopRequested": false}
```
Phone polls this endpoint every ~1.5s while recording. If `stopRequested` is `true`, the phone should stop recording. The flag auto-clears after being read.

### Upload Audio
```
POST /api/upload?filename=recording.wav
Authorization: Bearer {token}
Content-Type: multipart/form-data (or application/octet-stream)
Body: raw audio bytes
Response: {"id": "upload-uuid", "status": "received", "filename": "2026-04-18_15-30-00_localflow.wav"}
```

## Error Responses
- `401 Unauthorized` - Missing or invalid token
- `400 Bad Request` - Invalid request format
- `410 Gone` - Pairing code expired
- `403 Forbidden` - Invalid pairing code
- `503 Service Unavailable` - Server busy

## Audio Format
- Preferred: WAV mono 16kHz 16-bit PCM
- Also accepted: MP3, M4A, MP4
