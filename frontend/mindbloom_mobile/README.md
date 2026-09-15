# MindBloom Mobile

## Run application

Normal Android emulator development:

```powershell
cd frontend
.\scripts\run-mobile.ps1
```

The script uses the `MindBloom_API34_AOSP` emulator, waits for ADB/boot, checks that the API is reachable on the Windows host, and runs Flutter with:

```text
API_BASE_URL=http://10.0.2.2:5110
```

Windows desktop Flutter development should use the host loopback address:

```bash
flutter run ^
--dart-define=API_BASE_URL=http://localhost:5110 ^
--dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_your_key
```

## Notes

- Start MindBloom.API with the `http` profile so it listens on `http://0.0.0.0:5110`.
- Android emulator uses `10.0.2.2` instead of `localhost`.
- Docker-hosted API remains a separate path and uses port `8080`; do not mix that URL with the Visual Studio `http` profile.
- The application uses JWT authentication.
- Debug/profile Android builds allow local cleartext HTTP; release builds do not enable cleartext globally.
