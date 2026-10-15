# aiAssistant

가운데 입력창으로 일정, 장부, 날씨, 환율, 미국·일본 뉴스를 다루는 Flutter 웹 앱입니다.

## 로컬 실행

Flutter SDK가 PATH에 있어야 합니다. 이 작업 환경의 SDK는 `C:\dev\flutter\bin` 입니다.

```bash
flutter pub get
flutter run -d chrome
```

`flutter test`와 `flutter analyze`로 로직과 정적 검사를 확인합니다.

## Firebase

프로젝트 ID는 `aiassistant-49b02`, 리전은 `asia-northeast3` 입니다. 앱과 Cloud Functions는 Firestore 데이터베이스 `(default)` 를 사용합니다. 같은 프로젝트의 이름 있는 데이터베이스 `aiassistant` 는 앱이 읽거나 쓰지 않습니다.

콘솔에서 켤 항목:

- Authentication: 익명, Google. Google 웹 클라이언트는 이 프로젝트(번호 `148982182247`)에서 만든 클라이언트여야 합니다.
- Firestore `(default)`
- Storage 버킷 `aiassistant-49b02.firebasestorage.app`
- Functions

Firestore TTL 정책은 사용자가 콘솔에서 만듭니다.

- 컬렉션 그룹 `weather_logs`, 필드 `expireAt`
- 컬렉션 그룹 `exchange_logs`, 필드 `expireAt`

화면은 만료 시각이 지난 기록을 바로 숨깁니다. 날씨·환율 조회 함수도 지난 기록을 지웁니다. TTL은 그 뒤 서버가 지우는 보조 수단입니다.

## 서버 비밀

`GEMINI_MODEL`만 `functions/.env`에 둡니다. 이 값은 배포되는 일반 환경 변수이고, 기본 모델은 `gemini-3.8-flash` 입니다.

API 키는 `functions/.secret.local`에 둡니다. 이 파일은 배포되지 않고 git에도 올리지 않습니다. 같은 이름의 값이 Secret Manager에 있어야 배포된 함수가 읽습니다.

- `OPENWEATHER_API_KEY`
- `EXCHANGE_RATE_API_KEY`
- `GEMINI_API_KEY` — Google AI Studio의 Gemini API 키. 비어 있으면 대화 분류와 뉴스 스크립트가 실패합니다.

`submitPrompt`와 `scriptNews`는 `GEMINI_API_KEY`를 비밀로 읽습니다. 날씨·환율 함수도 같은 방식입니다. 키를 `.env`에 두면 비밀과 일반 환경 변수가 겹쳐 배포가 거절됩니다.

```bash
firebase functions:secrets:set OPENWEATHER_API_KEY
firebase functions:secrets:set EXCHANGE_RATE_API_KEY
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions,firestore,storage
```

## 배포

GitHub `main` 푸시 후 Vercel이 `tool/vercel-build.sh`로 웹을 빌드합니다. 모든 경로는 `index.html`로 되돌립니다.

원격 저장소: https://github.com/byki0304/aiassistant.git
