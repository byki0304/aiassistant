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
  String get emptyInput => _t(
        '내용을 입력하거나 파일을 선택해 주세요.',
        'Enter text or choose a file.',
        '文字を入力するか、ファイルを選んでください。',
      );
  String get saveFailed => _t(
        '저장하지 못했습니다. 연결 또는 입력 내용을 확인해 주세요.',
        'Nothing was saved. Check the connection or the input.',
        '保存できませんでした。接続か入力内容を確認してください。',
      );
  String get aiThinking => _t(
        '내용을 읽고 있습니다.',
        'Reading your input.',
        '内容を読んでいます。',
      );
  String get selectAll => _t('전체 선택', 'Select all', 'すべて選択');
  String get delete => _t('삭제', 'Delete', '削除');
  String deleteConfirm(int count) => _t(
        '선택한 $count개를 삭제합니다.',
        'Delete $count selected items.',
        '選択した$count件を削除します。',
      );
  String get cancel => _t('취소', 'Cancel', 'キャンセル');
  String selectedCount(int count) => _t('$count개 선택됨', '$count selected', '$count件選択');
  String get voiceBadge => _t('음성 입력', 'Voice', '音声');
  String savedBadge(String menu) => _t(
        '$menu 자동 저장됨 (이동)',
        'Saved to $menu (open)',
        '$menu に保存しました（開く）',
      );
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
    return _t(
      '$description : $sign$amount원',
      '$description : $sign$amount KRW',
      '$description : $sign$amountウォン',
    );
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
  String get searchRateFirst => _t(
        '먼저 환율을 검색해 주세요.',
        'Search an exchange rate first.',
        '先に為替を検索してください。',
      );
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
  String get fileTooBig => _t(
        '파일은 20MB까지 올릴 수 있습니다.',
        'Files can be up to 20MB.',
        'ファイルは20MBまでです。',
      );
  String get badExtension => _t(
        'txt, pdf, doc, docx, xls, xlsx, ppt, pptx만 올릴 수 있습니다.',
        'Only txt, pdf, doc, docx, xls, xlsx, ppt, and pptx files are accepted.',
        'txt, pdf, doc, docx, xls, xlsx, ppt, pptx のみアップロードできます。',
      );
  String get legacyOffice => _t(
        'docx, xlsx, pptx로 다시 저장해 주세요.',
        'Save the file again as docx, xlsx, or pptx.',
        'docx、xlsx、pptx で保存し直してください。',
      );
  String get geminiMissing => _t(
        'Gemini 키가 아직 없습니다. 날씨, 환율, 뉴스 버튼은 사용할 수 있습니다.',
        'The Gemini key is not set yet. Weather, exchange, and news buttons still work.',
        'Geminiの鍵が未設定です。天気・為替・ニュースのボタンは使えます。',
      );
  String get cityNotFound => _t(
        '도시를 찾지 못했습니다.',
        'That city was not found.',
        '都市が見つかりませんでした。',
      );
  String get signingIn => _t(
        '계정을 준비하고 있습니다.',
        'Preparing your account.',
        'アカウントを準備しています。',
      );
  String get authFailed => _t(
        '로그인하지 못했습니다. Firebase 익명 인증을 켜 주세요.',
        'Sign-in failed. Enable Anonymous auth in Firebase.',
        'ログインできませんでした。Firebaseの匿名認証を有効にしてください。',
      );
  String krwLine(String label, String value) => _t(
        '$label $value원',
        '$label $value KRW',
        '$label $valueウォン',
      );
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

  String expenseDraft(int amount) => _t(
        '오늘 지출 $amount원 등록',
        'Record an expense of $amount KRW today',
        '今日の支出$amountウォンを登録',
      );
}
