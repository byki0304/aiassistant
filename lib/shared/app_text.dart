import 'package:flutter/material.dart';

import 'logic/domain.dart';

class AppText {
  const AppText(this.languageCode);

  final String languageCode;

  factory AppText.of(Locale locale) => AppText(locale.languageCode);

  String _t(String ko, String en, String ja) {
    return switch (languageCode) {
      'en' => en,
      'ja' => ja,
      _ => ko,
    };
  }

  String get appTitle => 'aiAssistant';
  String get logout => _t('로그아웃', 'Log out', 'ログアウト');
  String get myPage => _t('마이페이지', 'My page', 'マイページ');
  String get welcome => _t(
    '말, 음성, 문서를 가운데 창에 넣으면 텍스트·표·도표로 답하고 해당 메뉴에 남깁니다.',
    'Type, speak, or drop a document in the center. Answers come back as text, tables, and charts, and matching menus keep them.',
    '中央の欄に文字・音声・文書を入れると、文章・表・グラフで答え、該当メニューに残します。',
  );
  String get emptyData => _t(
    '저장된 데이터가 없습니다. 중앙 AI 입력창으로 내용을 넣어 주세요.',
    'Nothing is stored yet. Add it from the center assistant.',
    '保存されたデータはありません。中央の入力欄から追加してください。',
  );
  String get emptyInput => _t('내용을 입력하거나 파일을 선택해 주세요.', 'Enter text or choose a file.', '文字を入力するか、ファイルを選んでください。');
  String get saveFailed =>
      _t('저장하지 못했습니다. 연결 또는 입력 내용을 확인해 주세요.', 'Nothing was saved. Check the connection or the input.', '保存できませんでした。接続か入力内容を確認してください。');
  String get aiThinking => _t('내용을 읽고 있습니다.', 'Reading your input.', '内容を読んでいます。');
  String get selectAll => _t('전체 선택', 'Select all', 'すべて選択');
  String get delete => _t('삭제', 'Delete', '削除');
  String get selectPrompt => _t('입력 내용 선택', 'Select this prompt', '入力内容を選択');
  String get selectAnswer => _t('출력 내용 선택', 'Select this answer', '出力内容を選択');
  String deleteConfirm(int count) => _t('선택한 $count개를 삭제합니다.', 'Delete $count selected items.', '選択した$count件を削除します。');
  String get cancel => _t('취소', 'Cancel', 'キャンセル');
  String selectedCount(int count) => _t('$count개 선택됨', '$count selected', '$count件選択');
  String get voiceBadge => _t('음성 입력', 'Voice', '音声');
  String savedBadge(String menu) => _t("'$menu' 자동 저장됨 (바로가기)", 'Saved to $menu (open)', '$menu に保存しました（開く）');
  String get presetBalance => _t('이번 주 장부 요약 도표', 'This week balance chart', '今週の帳簿グラフ');
  String get presetNews => _t('미·일 주요 뉴스 브리핑', 'US and Japan news briefing', '米日ニュース要約');
  String get presetWeather => _t('성남·요코하마 날씨 비교', 'Seongnam and Yokohama weather', '城南と横浜の天気');
  String approveSchedules(int count) => _t('일정 $count건 등록', 'Save $count schedules', '予定$count件を登録');
  String approveBalances(int count) => _t('금액 $count건 기입', 'Save $count amounts', '金額$count件を記帳');
  String get weekExpense => _t('지출', 'Expense', '支出');
  String get weekIncome => _t('수입', 'Income', '収入');
  String get weekNet => _t('주간 순액', 'Week net', '今週の差引');
  String get prevWeek => _t('이전 주', 'Previous week', '前の週');
  String get nextWeek => _t('다음 주', 'Next week', '次の週');
  String balanceLine(String description, int amount, bool isIncome) {
    final sign = isIncome ? '+' : '-';
    return _t('$description : $sign$amount원', '$description : $sign$amount KRW', '$description : $sign$amountウォン');
  }

  String runningBalance(int amount) => _t('잔액: $amount원', 'Balance: $amount KRW', '残高: $amountウォン');
  String remaining(int hours) => _t('$hours시간 후 삭제', 'Deletes in $hours h', '$hours時間後に削除');
  String get usNews => _t('미국 뉴스', 'US news', '米国ニュース');
  String get jpNews => _t('일본 뉴스', 'Japan news', '日本ニュース');
  String get script => _t('스크립트', 'Script', 'スクリプト');
  String get weatherEmpty => _t(
    '아직 검색한 날씨가 없습니다. 도시 버튼을 누르거나 중앙 입력창에 도시를 말해 주세요.',
    'No weather searches yet. Use a city button or ask in the center.',
    'まだ天気の検索はありません。都市ボタンか中央の入力を使ってください。',
  );
  String get exchangeEmpty => _t(
    '아직 검색한 환율이 없습니다. 통화 버튼을 누르거나 중앙 입력창에 말해 주세요.',
    'No exchange searches yet. Use a currency button or ask in the center.',
    'まだ為替の検索はありません。通貨ボタンか中央の入力を使ってください。',
  );
  String get searchRateFirst => _t('먼저 환율을 검색해 주세요.', 'Search an exchange rate first.', '先に為替を検索してください。');
  String get popup => 'PopUp';
  String get applyRate => _t('환율 적용', 'Apply rate', '為替を適用');
  String get sendToBalance => _t('장부로 보내기', 'Send to balance', '帳簿へ送る');
  String get withdraw => _t('탈퇴', 'Delete account', '退会');
  String get withdrawConfirm => _t(
    '계정과 일정, 장부, 뉴스, 날씨, 환율, 대화, 업로드 파일을 삭제합니다.',
    'This deletes the account and schedules, balance, news, weather, exchange rates, chat, and uploaded files.',
    'アカウントと予定、帳簿、ニュース、天気、為替、会話、アップロードファイルを削除します。',
  );
  String get linkGoogle => _t('Google 계정 연결', 'Link Google', 'Googleアカウントを連携');
  String get language => _t('언어', 'Language', '言語');
  String get guest => _t('비회원', 'Guest', 'ゲスト');
  String get linked => _t('Google 연결됨', 'Google linked', 'Google連携済み');
  String get year => _t('년', 'Year', '年');
  String get month => _t('월', 'Month', '月');
  String get week => _t('주', 'Week', '週');
  String get day => _t('일', 'Day', '日');
  String get accountTitle => _t('마이페이지', 'My page', 'マイページ');
  String get closeAccount => _t('닫기', 'Close', '閉じる');
  String get fileTooBig => _t('파일은 20MB까지 올릴 수 있습니다.', 'Files can be up to 20MB.', 'ファイルは20MBまでです。');
  String get badExtension => _t(
    'txt, pdf, doc, docx, xls, xlsx, ppt, pptx만 올릴 수 있습니다.',
    'Only txt, pdf, doc, docx, xls, xlsx, ppt, and pptx files are accepted.',
    'txt, pdf, doc, docx, xls, xlsx, ppt, pptx のみアップロードできます。',
  );
  String get legacyOffice =>
      _t('docx, xlsx, pptx로 다시 저장해 주세요.', 'Save the file again as docx, xlsx, or pptx.', 'docx、xlsx、pptx で保存し直してください。');
  String get geminiMissing => _t(
    'Gemini 키가 아직 없습니다. 날씨, 환율, 뉴스 버튼은 사용할 수 있습니다.',
    'The Gemini key is not set yet. Weather, exchange, and news buttons still work.',
    'Geminiの鍵が未設定です。天気・為替・ニュースのボタンは使えます。',
  );
  String get cityNotFound => _t('도시를 찾지 못했습니다.', 'That city was not found.', '都市が見つかりませんでした。');
  String get signingIn => _t('계정을 준비하고 있습니다.', 'Preparing your account.', 'アカウントを準備しています。');
  String get authFailed =>
      _t('로그인하지 못했습니다. 잠시 후 다시 시도해 주세요.', 'Sign-in failed. Try again in a moment.', 'ログインできませんでした。しばらくしてからもう一度お試しください。');
  String get loginTitle => _t('통합 AI 업무 어시스턴트', 'Your all-in-one AI work assistant', '統合AI業務アシスタント');
  String get loginSubtitle => _t(
    '말, 음성, 문서 하나로 일정·장부·날씨·환율·뉴스를 정리합니다.',
    'One sentence, voice note, or document keeps schedules, balance, weather, rates, and news in order.',
    'ひと言・音声・文書で、予定・帳簿・天気・為替・ニュースを整理します。',
  );
  String get googleLogin => _t('Google로 로그인', 'Sign in with Google', 'Googleでログイン');
  String get guestStart => _t('게스트로 시작', 'Start as guest', 'ゲストで始める');
  String get guestNote => _t(
    '게스트 기록은 이 브라우저에 연결됩니다. 나중에 마이페이지에서 Google 계정을 연결할 수 있습니다.',
    'Guest records stay with this browser. You can link Google later from My page.',
    'ゲストの記録はこのブラウザに紐づきます。後でマイページからGoogleを連携できます。',
  );
  String get emailLogin => _t('이메일 로그인', 'Sign in with email', 'メールでログイン');
  String get phoneLogin => _t('휴대폰번호 로그인', 'Sign in with phone', '電話番号でログイン');
  String get signupPrompt => _t('처음이면 신규가입', 'New here? Sign up', '初めての方は新規登録');
  String get signup => _t('회원 가입', 'Sign up', '新規登録');
  String get emailLabel => _t('이메일 주소', 'Email', 'メールアドレス');
  String get passwordLabel => _t('비밀번호', 'Password', 'パスワード');
  String get passwordConfirmLabel => _t('비밀번호 확인', 'Confirm password', 'パスワード（確認）');
  String get passwordRule => _t('6자 이상', 'At least 6 characters', '6文字以上');
  String get keepSignedIn => _t('로그인 상태 유지', 'Keep me signed in', 'ログイン状態を保持');
  String get showPassword => _t('비밀번호 보기', 'Show password', 'パスワードを表示');
  String get findPassword => _t('비밀번호 찾기', 'Forgot password', 'パスワードを忘れた');
  String get loginAction => _t('로그인', 'Sign in', 'ログイン');
  String get backToOptions => _t('다른 방법으로 로그인', 'Other sign-in options', '他の方法でログイン');
  String get haveAccount => _t('이미 계정이 있으면 로그인', 'Have an account? Sign in', 'アカウントをお持ちの方はログイン');
  String get phoneLabel => _t('휴대폰번호', 'Phone number', '電話番号');
  String get phoneHint => _t('10-1234-5678', '10-1234-5678', '90-1234-5678');
  String get countryCodeLabel => _t('국가번호', 'Country code', '国番号');
  String get phoneSignupInstead => _t('휴대폰번호로 가입', 'Sign up with phone instead', '電話番号で登録');
  String get emailSignupInstead => _t('이메일로 가입', 'Sign up with email instead', 'メールで登録');
  String resetSent(String email) => _t('$email 로 비밀번호 재설정 메일을 보냈습니다.', 'A reset link was sent to $email.', '$email にパスワード再設定メールを送りました。');
  String get needEmailForReset => _t('비밀번호를 찾을 이메일 주소를 먼저 입력해 주세요.', 'Enter your email first.', '先にメールアドレスを入力してください。');
  String authError(String code) => switch (code) {
    'invalid-email' => _t('이메일 형식이 올바르지 않습니다.', 'That email address is not valid.', 'メールアドレスの形式が正しくありません。'),
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'invalid-login-credentials' => _t('이메일 또는 비밀번호가 맞지 않습니다.', 'Email or password is incorrect.', 'メールアドレスまたはパスワードが違います。'),
    'email-already-in-use' => _t('이미 가입된 이메일입니다. 로그인해 주세요.', 'This email is already registered. Please sign in.', '登録済みのメールです。ログインしてください。'),
    'weak-password' => _t('비밀번호는 6자 이상이어야 합니다.', 'Use at least 6 characters.', 'パスワードは6文字以上にしてください。'),
    'missing-password' => _t('비밀번호를 입력해 주세요.', 'Enter your password.', 'パスワードを入力してください。'),
    'missing-email' => _t('이메일 주소를 입력해 주세요.', 'Enter your email.', 'メールアドレスを入力してください。'),
    'password-mismatch' => _t('비밀번호가 서로 다릅니다.', 'Passwords do not match.', 'パスワードが一致しません。'),
    'invalid-phone-number' || 'missing-phone-number' => _t('휴대폰번호를 확인해 주세요.', 'Check the phone number.', '電話番号を確認してください。'),
    'phone-invalid-credential' => _t('휴대폰번호 또는 비밀번호가 맞지 않습니다.', 'Phone number or password is incorrect.', '電話番号またはパスワードが違います。'),
    'phone-already-in-use' => _t(
      '이미 가입된 휴대폰번호입니다. 로그인해 주세요.',
      'This phone number is already registered. Please sign in.',
      '登録済みの電話番号です。ログインしてください。',
    ),
    'too-many-requests' ||
    'quota-exceeded' => _t('요청이 많습니다. 잠시 후 다시 시도해 주세요.', 'Too many attempts. Try again later.', '試行回数が多すぎます。しばらくしてからお試しください。'),
    'operation-not-allowed' ||
    'admin-restricted-operation' => _t('이 로그인 방법이 아직 활성화되지 않았습니다.', 'This sign-in method is not enabled yet.', 'このログイン方法はまだ有効になっていません。'),
    _ => authFailed,
  };
  String get homeChat => _t('대화 홈', 'Chat home', '会話ホーム');
  String get closeMenu => _t('대화 화면으로', 'Back to chat', '会話に戻る');
  String openMenu(String menu) => _t('$menu 바로가기', 'Open $menu', '$menuへ');
  String get soundOn => _t('소리 켜기', 'Sound on', '音を出す');
  String get soundOff => _t('소리 끄기', 'Sound off', '消音');
  String get skipIntro => _t('건너뛰기', 'Skip', 'スキップ');
  String get introSetting => _t('시작할 때 인트로 영상 보기', 'Play the intro on start', '起動時にイントロを再生');
  String get fontSize => _t('글자크기', 'Text size', '文字サイズ');
  String get lineSpacing => _t('줄간 거리', 'Line spacing', '行間');
  String get smaller => _t('작게', 'Smaller', '小さく');
  String get larger => _t('크게', 'Larger', '大きく');
  String get narrower => _t('좁게', 'Tighter', '狭く');
  String get wider => _t('넓게', 'Wider', '広く');
  String get defaultLevel => _t('기본', 'Default', '標準');
  String levelOf(int level) => _t('$level단계', 'Level $level', '$level段階');
  String get readingPreview => _t(
    '오늘 오후 3시 회의, 점심값 12,000원. 글자와 줄 간격이 이렇게 보입니다.',
    'Meeting at 3 pm, lunch ₩12,000. This is how text and line spacing look.',
    '今日の午後3時に会議、昼食代12,000ウォン。文字と行間はこのように見えます。',
  );
  String get uploadFile => _t('파일 업로드', 'Upload file', 'ファイル');
  String get runAi => _t('AI 실행', 'Run AI', 'AI実行');
  String get inputHint => _t(
    '일정, 장부, 날씨, 환율, 뉴스 검색과 파일 분석을 이곳에 입력하세요.',
    'Ask about schedules, balance, weather, rates, news, or a file.',
    '予定・帳簿・天気・為替・ニュース・ファイル分析をここに入力してください。',
  );
  String get inputTitle => _t('AI Assistant 입력창', 'AI Assistant input', 'AI Assistant 入力');
  String get outputTitle => _t('대화 & 분석 결과', 'Chat & results', '会話と分析結果');
  String get listening => _t('듣는 중…', 'Listening…', '聞いています…');
  String countLabel(String label, int count) => _t('$label ($count건)', '$label ($count)', '$label（$count件）');
  String get weekBook => _t('주간 장부', 'Weekly ledger', '週間帳簿');
  String get currentBalance => _t('현재 잔액', 'Balance', '現在残高');
  String get todayExpense => _t('오늘 지출', 'Spent today', '今日の支出');
  String get todayIncome => _t('오늘 수입', 'Received today', '今日の収入');
  String get todayEntries => _t('오늘의 지출·수입 내역', 'Today’s entries', '今日の入出金');
  String get columnDate => _t('날짜', 'Date', '日付');
  String get columnTime => _t('시간', 'Time', '時間');
  String get columnKind => _t('지출/수입', 'Type', '支出/収入');
  String get columnDescription => _t('내역', 'Details', '内訳');
  String get columnAmount => _t('금액', 'Amount', '金額');
  String get selectEntry => _t('내역 선택', 'Select entry', '項目を選択');
  String get expandRow => _t('전체 내용 보기', 'Show everything', '全文を表示');
  String get collapseRow => _t('원래 크기로', 'Show less', '元の大きさに戻す');
  String get scheduleList => _t('등록된 스케줄 목록', 'Saved schedules', '登録済みの予定');
  String get calcHistory => _t('계산 기록', 'Calculation history', '計算履歴');
  String get calcHistoryEmpty => _t('= 을 누르면 계산 결과가 여기에 남습니다.', 'Press = and the result is kept here.', '= を押すと計算結果がここに残ります。');
  String get cancelledBadge => _t('취소됨', 'Cancelled', 'キャンセル済み');
  String get allDates => _t('전체', 'All', 'すべて');
  String get pickDates => _t('달력에서 날짜를 눌러 일정을 보세요.', 'Tap dates on the calendar to see their schedules.', 'カレンダーの日付を押すと予定が表示されます。');
  String pageLabel(int page) => _t('$page 페이지', 'Page $page', '$pageページ');
  String get weekEntries => _t('주 단위 입출금 내역', 'This week’s entries', '今週の入出金');
  String get citySearch => _t('주요 도시 실시간 날씨', 'Live weather by city', '主要都市の天気');
  String get weatherHistory => _t('최근 검색한 도시 날씨', 'Recent weather lookups', '最近の天気検索');
  String get currencySearch => _t('주요 6대 통화 환율 (KRW 기준)', 'Six major currencies in KRW', '主要6通貨（KRW基準）');
  String get exchangeHistory => _t('최근 검색한 환율', 'Recent rate lookups', '最近の為替検索');
  String get newsHeadline => _t('미국 · 일본 오늘의 뉴스', 'Today in the US and Japan', '米国・日本の今日のニュース');
  String get latestFive => _t('최신 5개 보기', 'Latest 5', '最新5件');
  String get newsArchive => _t("Today's News 아카이브", "Today's News archive", "Today's News アーカイブ");
  String get calcTitle => _t('기본 계산기', 'Calculator', '電卓');
  String get dragMove => 'Drag & Move';
  String get profile => _t('사용자 프로필', 'Profile', 'プロフィール');
  String get settings => _t('설정', 'Settings', '設定');
  String get services => _t('연동 서비스', 'Connected services', '連携サービス');
  String get primaryDb => _t('Firebase · 주 DB', 'Firebase · primary DB', 'Firebase・メインDB');
  String get backupDb => _t('Google Cloud · 보조 DB', 'Google Cloud · backup DB', 'Google Cloud・予備DB');
  String get dbChecking => _t('확인 중', 'Checking', '確認中');
  String get dbUnavailable => _t('연결 안 됨', 'Unavailable', '未接続');
  String dbCount(int count) => _t('$count건 저장', '$count stored', '$count件保存');
  String get syncBackup => _t('보조 DB 동기화', 'Sync backup', '予備DBを同期');
  String synced(int count) => _t('보조 DB로 $count건을 복사했습니다.', 'Copied $count items to the backup.', '予備DBへ$count件コピーしました。');
  String get backupBanner => _t(
    'Firebase 연결이 끊겨 Google Cloud 보조 DB에서 읽는 중',
    'Firebase is unreachable; reading from the Google Cloud backup',
    'Firebaseに接続できないため予備DBから読み込み中',
  );
  String get resetMemory => _t('AI 대화 기록 초기화', 'Clear chat history', '会話履歴を消去');
  String resetConfirm(int count) => _t('AI 대화 기록 $count건을 지웁니다.', 'Delete $count chat turns.', '会話履歴$count件を削除します。');
  String chatCount(int count) => _t('AI 대화 기록 $count건', '$count chat turns', '会話履歴$count件');
  String get guestLogoutWarn => _t(
    '게스트로 로그아웃하면 이 기록으로 다시 들어올 수 없습니다. 먼저 Google 계정을 연결하면 기록이 유지됩니다.',
    'Logging out of a guest account loses access to these records. Link Google first to keep them.',
    'ゲストでログアウトすると、この記録には戻れません。先にGoogleを連携すると記録が残ります。',
  );
  String get refresh => _t('새로고침', 'Refresh', '更新');
  String lastMirrored(String time) => _t('마지막 복제 $time', 'Last mirrored $time', '最終複製 $time');
  String get noEmail => _t('이메일 없음 (게스트)', 'No email (guest)', 'メールなし（ゲスト）');
  String krwLine(String label, String value) => _t('$label $value원', '$label $value KRW', '$label $valueウォン');
  String menuName(String id) {
    return switch (id) {
      'schedules' || 'schedule' => _t('My Schedules', 'My Schedules', 'マイスケジュール'),
      'balance' => _t('My Balance', 'My Balance', 'マイバランス'),
      'weather' => _t('Weather', 'Weather', '天気'),
      'exchange' || 'exchangeRate' => _t('Exchange Rate', 'Exchange Rate', '為替'),
      'news' => _t("Today's News", "Today's News", '今日のニュース'),
      'calculator' => _t('Calculator', 'Calculator', '電卓'),
      _ => _t('일반', 'General', '一般'),
    };
  }

  String currencyLabel(CurrencyPreset preset) => preset.label(languageCode);

  String expenseDraft(int amount) => _t('오늘 지출 $amount원 등록', 'Record an expense of $amount KRW today', '今日の支出$amountウォンを登録');
}
