# MindBloom Mobile

## Run application

Android emulator:

```bash
flutter run ^
--dart-define=API_BASE_URL=http://10.0.2.2:5110
```

Windows:

```bash
flutter run ^
--dart-define=API_BASE_URL=http://localhost:5110
```

## Notes

- API_BASE_URL must point to the running MindBloom API.
- Android emulator uses 10.0.2.2 instead of localhost.
- The application uses JWT authentication.