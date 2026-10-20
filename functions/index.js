const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getStorage } = require('firebase-admin/storage');
const { defineSecret } = require('firebase-functions/params');
const { XMLParser } = require('fast-xml-parser');

initializeApp({
  storageBucket: 'aiassistant-49b02.firebasestorage.app',
});

const openWeatherKey = defineSecret('OPENWEATHER_API_KEY');
const exchangeKey = defineSecret('EXCHANGE_RATE_API_KEY');
const geminiApiKey = defineSecret('GEMINI_API_KEY');

const region = 'asia-northeast3';
const databaseId = 'aiassistant';

// Firebase (Firestore `aiassistant`) is the primary store; every user document is mirrored
// into the Google Cloud Firestore database `aiassistant-backup`, which serves reads only
// when the primary is unreachable.
const backupDatabaseId = 'aiassistant-backup';
const mirroredCollections = ['schedules', 'balance_entries', 'news_items', 'weather_logs', 'exchange_logs', 'turns'];

function db() {
  return getFirestore(databaseId);
}

function backupDb() {
  return getFirestore(backupDatabaseId);
}

function backupCol(uid, name) {
  return backupDb().collection('users').doc(uid).collection(name);
}

function plain(value) {
  if (value instanceof Timestamp) {
    return value.toDate().toISOString();
  }
  if (Array.isArray(value)) {
    return value.map(plain);
  }
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, plain(item)]));
  }
  return value;
}
// Everything a user enters or receives is kept at most this long, in every store; schedules and ledger entries
// (`recordCollections`) are kept longer.
const memberRetentionMs = 240 * 60 * 60 * 1000;
const guestRetentionMs = 72 * 60 * 60 * 1000;
const memberRecordRetentionMs = 12000 * 60 * 60 * 1000;
const guestRecordRetentionMs = 2400 * 60 * 60 * 1000;
const recordCollections = ['schedules', 'balance_entries'];

function retentionFor(request) {
  return request.auth?.token?.firebase?.sign_in_provider === 'anonymous' ? guestRetentionMs : memberRetentionMs;
}

function readSecret(param) {
  try {
    const value = param.value();
    if (value) {
      return value;
    }
  } catch (_) {
    // Emulator and local runs fall through to the environment.
  }
  return process.env[param.name] || '';
}

function requireUid(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'unauthenticated');
  }
  return request.auth.uid;
}

function userCol(uid, name) {
  return db().collection('users').doc(uid).collection(name);
}

async function audit(uid, action, targetId, fields) {
  await db().collection('audit').add({
    action,
    actorUid: uid,
    targetId,
    at: FieldValue.serverTimestamp(),
    fields,
  });
}

function seoulToUtc(year, month, day, hour, minute) {
  return new Date(Date.UTC(year, month - 1, day, hour - 9, minute, 0));
}

function parseWhen(value, hour, minute) {
  if (!value) {
    return null;
  }
  const text = String(value).trim();
  const dateOnly = text.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (dateOnly) {
    return seoulToUtc(Number(dateOnly[1]), Number(dateOnly[2]), Number(dateOnly[3]), hour, minute);
  }
  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed;
}

async function saveSchedule(uid, draft) {
  const title = String(draft?.title || '').trim().slice(0, 200);
  if (!title) {
    return null;
  }
  const allDay = draft.allDay === true;
  const start = parseWhen(draft.startAt, allDay ? 0 : 9, 0);
  if (!start) {
    return null;
  }
  let end = parseWhen(draft.endAt, allDay ? 23 : 10, allDay ? 59 : 0);
  if (!end || end <= start) {
    end = new Date(start.getTime() + 60 * 60 * 1000);
  }
  const ref = userCol(uid, 'schedules').doc();
  await ref.set({
    uid,
    title,
    startAt: Timestamp.fromDate(start),
    endAt: Timestamp.fromDate(end),
    allDay,
    createdAt: Timestamp.fromDate(new Date()),
  });
  await audit(uid, 'create', ref.id, ['title', 'startAt', 'endAt', 'allDay']);
  return ref.id;
}

/** Moves an existing schedule to the new time; a missing end keeps the old duration. */
async function rescheduleSchedule(uid, targetId, draft) {
  const snap = await findTarget(uid, 'schedules', targetId, 'title', draft?.title);
  if (!snap) {
    return null;
  }
  const ref = snap.ref;
  const allDay = typeof draft?.allDay === 'boolean' ? draft.allDay : snap.get('allDay') === true;
  const oldStart = snap.get('startAt').toDate();
  const oldEnd = snap.get('endAt').toDate();
  let end = parseWhen(draft?.endAt, allDay ? 23 : 10, allDay ? 59 : 0);
  let start = parseWhen(draft?.startAt, allDay ? 0 : 9, 0);
  if (!start && end) {
    start = new Date(end.getTime() - Math.max(oldEnd.getTime() - oldStart.getTime(), 30 * 60 * 1000));
  }
  if (!start) {
    return null;
  }
  if (!end || end <= start) {
    end = new Date(start.getTime() + Math.max(oldEnd.getTime() - oldStart.getTime(), 30 * 60 * 1000));
  }
  await ref.update({
    startAt: Timestamp.fromDate(start),
    endAt: Timestamp.fromDate(end),
    allDay,
    movedFrom: Timestamp.fromDate(oldStart),
    cancelled: false,
    updatedAt: Timestamp.fromDate(new Date()),
  });
  await audit(uid, 'reschedule', ref.id, ['startAt', 'endAt', 'movedFrom']);
  return ref.id;
}

async function cancelSchedule(uid, targetId, title) {
  const snap = await findTarget(uid, 'schedules', targetId, 'title', title);
  if (!snap) {
    return null;
  }
  const ref = snap.ref;
  await ref.update({ cancelled: true, cancelledAt: Timestamp.fromDate(new Date()) });
  await audit(uid, 'cancel', ref.id, ['cancelled']);
  return ref.id;
}

function seoulIso(date) {
  return new Date(date.getTime() + 9 * 60 * 60 * 1000).toISOString().slice(0, 16) + '+09:00';
}

/** Schedules the model may move or cancel: 60 days back to a year ahead, as `id | title | start | state` lines. */
async function scheduleContext(uid) {
  const now = Date.now();
  const snap = await userCol(uid, 'schedules')
    .where('startAt', '>=', Timestamp.fromDate(new Date(now - 60 * 24 * 60 * 60 * 1000)))
    .where('startAt', '<=', Timestamp.fromDate(new Date(now + 400 * 24 * 60 * 60 * 1000)))
    .orderBy('startAt')
    .limit(120)
    .get();
  return snap.docs
    .map((doc) => {
      const title = String(doc.get('title') || '').replace(/[|\n]/g, ' ');
      return `${doc.id} | ${title} | ${seoulIso(doc.get('startAt').toDate())} | ${doc.get('cancelled') === true ? 'cancelled' : 'active'}`;
    })
    .join('\n');
}

async function recalculateBalances(uid) {
  const snap = await userCol(uid, 'balance_entries').orderBy('occurredAt').orderBy('__name__').get();
  let running = 0;
  let batch = db().batch();
  let count = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    running += data.isIncome ? Number(data.amount) : -Number(data.amount);
    batch.update(doc.ref, { runningBalance: running });
    count += 1;
    if (count === 400) {
      await batch.commit();
      batch = db().batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
}

function balanceAmount(value) {
  const amount = Math.round(Number(String(value ?? '').replace(/,/g, '')));
  return Number.isFinite(amount) && amount > 0 && amount <= 1e12 ? amount : null;
}

async function saveBalance(uid, draft, { recalculate = true } = {}) {
  const description = String(draft?.description || '').trim().slice(0, 200);
  const amount = balanceAmount(draft?.amount);
  if (!description || amount == null) {
    return null;
  }
  const occurred = parseWhen(draft.occurredAt, 12, 0) || new Date();
  const ref = userCol(uid, 'balance_entries').doc();
  await ref.set({
    uid,
    description,
    amount,
    isIncome: draft.isIncome === true,
    occurredAt: Timestamp.fromDate(occurred),
    runningBalance: 0,
    createdAt: Timestamp.fromDate(new Date()),
  });
  if (recalculate) {
    await recalculateBalances(uid);
  }
  await audit(uid, 'create', ref.id, ['description', 'amount', 'isIncome', 'occurredAt']);
  return ref.id;
}

/**
 * Finds the document the model means: its id when it exists, otherwise the only document whose `field` equals `label`.
 */
async function findTarget(uid, collection, targetId, field, label) {
  const id = String(targetId || '').trim();
  if (id && !id.includes('/')) {
    const snap = await userCol(uid, collection).doc(id).get();
    if (snap.exists) {
      return snap;
    }
  }
  const wanted = String(label || '').trim();
  if (!wanted) {
    console.warn('target not found', { collection, hasId: Boolean(id) });
    return null;
  }
  const matches = await userCol(uid, collection).where(field, '==', wanted).limit(2).get();
  if (matches.size === 1) {
    return matches.docs[0];
  }
  if (matches.size === 0) {
    // The model sometimes pads the label with extra words, so accept the one entry whose label it contains or that contains it.
    const recent = await userCol(uid, collection).limit(300).get();
    const loose = recent.docs.filter((doc) => {
      const own = String(doc.get(field) || '').trim();
      return own && (wanted.includes(own) || own.includes(wanted));
    });
    if (loose.length === 1) {
      return loose[0];
    }
    console.warn('target not found', { collection, hasId: Boolean(id), loose: loose.length });
    return null;
  }
  console.warn('target not found', { collection, hasId: Boolean(id), matches: matches.size });
  return null;
}

/** Corrects the fields the model gave for an existing entry; the caller recalculates balances. */
async function updateBalance(uid, targetId, draft) {
  const snap = await findTarget(uid, 'balance_entries', targetId, 'description', draft?.description);
  if (!snap) {
    return null;
  }
  const ref = snap.ref;
  const changes = {};
  const description = String(draft?.description || '').trim().slice(0, 200);
  if (description) {
    changes.description = description;
  }
  const amount = balanceAmount(draft?.amount);
  if (amount != null) {
    changes.amount = amount;
  }
  if (typeof draft?.isIncome === 'boolean') {
    changes.isIncome = draft.isIncome;
  }
  const occurred = parseWhen(draft?.occurredAt, 12, 0);
  if (occurred) {
    changes.occurredAt = Timestamp.fromDate(occurred);
  }
  if (Object.keys(changes).length === 0) {
    console.warn('balance update has no fields');
    return null;
  }
  await ref.update({ ...changes, updatedAt: Timestamp.fromDate(new Date()) });
  await audit(uid, 'update', ref.id, Object.keys(changes));
  return ref.id;
}

async function deleteBalance(uid, targetId, description) {
  const snap = await findTarget(uid, 'balance_entries', targetId, 'description', description);
  if (!snap) {
    return null;
  }
  const ref = snap.ref;
  await ref.delete();
  await audit(uid, 'delete', ref.id, ['id']);
  return ref.id;
}

/** Applies the model's ledger changes in order and recalculates once; returns how many took effect. */
async function applyBalanceChanges(uid, changes) {
  let applied = 0;
  for (const change of changes.slice(0, 20)) {
    const id = change?.action === 'delete'
      ? await deleteBalance(uid, change.targetId, change.description)
      : change?.action === 'update'
        ? await updateBalance(uid, change.targetId, change)
        : await saveBalance(uid, change, { recalculate: false });
    if (id) {
      applied += 1;
    }
  }
  if (applied > 0) {
    await recalculateBalances(uid);
  }
  return applied;
}

/** Recent ledger entries the model may correct or remove, as `id | description | in/out | amount | when` lines. */
async function balanceContext(uid) {
  const snap = await userCol(uid, 'balance_entries')
    .where('occurredAt', '>=', Timestamp.fromDate(new Date(Date.now() - 60 * 24 * 60 * 60 * 1000)))
    .orderBy('occurredAt', 'desc')
    .limit(80)
    .get();
  return snap.docs
    .map((doc) => {
      const description = String(doc.get('description') || '').replace(/[|\n]/g, ' ');
      const kind = doc.get('isIncome') === true ? 'income' : 'expense';
      return `${doc.id} | ${description} | ${kind} | ${doc.get('amount')} | ${seoulIso(doc.get('occurredAt').toDate())}`;
    })
    .join('\n');
}

async function purgeExpired(uid, name) {
  const snap = await userCol(uid, name).where('expireAt', '<', Timestamp.now()).get();
  if (snap.empty) {
    return;
  }
  const batch = db().batch();
  snap.docs.forEach((doc) => batch.delete(doc.ref));
  await batch.commit();
}

const cityQueries = {
  서울: 'Seoul,KR',
  yokohama: 'Yokohama,JP',
  요코하마: 'Yokohama,JP',
  singapore: 'Singapore,SG',
  싱가포르: 'Singapore,SG',
  '경기도 성남시': 'Seongnam,KR',
  성남: 'Seongnam,KR',
  부산: 'Busan,KR',
};

const defaultCityQuery = 'Seoul,KR';

function resolveCityQuery(input) {
  const text = String(input || '').trim();
  return cityQueries[text] || cityQueries[text.toLowerCase()] || text || defaultCityQuery;
}

function lang2(locale) {
  const lang = String(locale || '').slice(0, 2);
  return ['ko', 'en', 'ja'].includes(lang) ? lang : 'ko';
}

/** Today's calendar date in Asia/Seoul as YYYY-MM-DD. */
function seoulToday() {
  return seoulIso(new Date()).slice(0, 10);
}

function validDate(value) {
  const text = String(value || '').trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(text) && !Number.isNaN(Date.parse(`${text}T00:00:00Z`)) ? text : '';
}

function daysBetween(from, to) {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / (24 * 60 * 60 * 1000));
}

function dateLabel(date, locale) {
  const tag = { ko: 'ko-KR', en: 'en-US', ja: 'ja-JP' }[lang2(locale)];
  return new Intl.DateTimeFormat(tag, { month: 'long', day: 'numeric', weekday: 'short', timeZone: 'UTC' }).format(
    new Date(`${date}T00:00:00Z`),
  );
}

async function geocode(query, key) {
  const geoRes = await fetch(
    `https://api.openweathermap.org/geo/1.0/direct?q=${encodeURIComponent(query)}&limit=1&appid=${key}`,
  );
  const geo = await geoRes.json();
  return Array.isArray(geo) && geo.length > 0 ? { lat: geo[0].lat, lon: geo[0].lon } : null;
}

async function fetchWeather(query, key, locale = 'ko') {
  const place = await geocode(query, key);
  if (!place) {
    return null;
  }
  const owLang = { ko: 'kr', en: 'en', ja: 'ja' }[lang2(locale)];
  const weatherRes = await fetch(
    `https://api.openweathermap.org/data/2.5/weather?lat=${place.lat}&lon=${place.lon}&units=metric&lang=${owLang}&appid=${key}`,
  );
  const weather = await weatherRes.json();
  if (!weather.main) {
    return null;
  }
  return {
    temperature: weather.main.temp,
    condition: weather.weather && weather.weather[0] ? weather.weather[0].description : '',
    humidity: weather.main.humidity,
  };
}

const weatherCodeText = [
  [[0], '맑음', 'Clear', '晴れ'],
  [[1, 2], '구름 조금', 'Partly cloudy', '晴れ時々曇り'],
  [[3], '흐림', 'Overcast', '曇り'],
  [[45, 48], '안개', 'Fog', '霧'],
  [[51, 53, 55, 56, 57], '이슬비', 'Drizzle', '霧雨'],
  [[61, 63, 65, 66, 67, 80, 81, 82], '비', 'Rain', '雨'],
  [[71, 73, 75, 77, 85, 86], '눈', 'Snow', '雪'],
  [[95, 96, 99], '뇌우', 'Thunderstorm', '雷雨'],
];

function weatherCodeName(code, locale) {
  const row = weatherCodeText.find(([codes]) => codes.includes(Number(code)));
  const index = { ko: 1, en: 2, ja: 3 }[lang2(locale)];
  return row ? row[index] : '';
}

function addDays(date, days) {
  return new Date(Date.parse(`${date}T00:00:00Z`) + days * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

const maxForecastDays = 15;

/**
 * Daily weather from `start` to `end` at the place: Open-Meteo forecast covers the last two months and the next 15 days,
 * its archive covers older dates. Days past the forecast range are dropped (`cutAfter` says from when); returns null
 * when no asked day has data.
 */
async function fetchDailyWeather(query, start, end, key, locale) {
  const today = seoulToday();
  const lastForecast = addDays(today, maxForecastDays);
  if (start > lastForecast) {
    return null;
  }
  const last = end > lastForecast ? lastForecast : end;
  const place = await geocode(query, key);
  if (!place) {
    return null;
  }
  const archive = daysBetween(today, start) < -60;
  const fields = archive
    ? 'weather_code,temperature_2m_max,temperature_2m_min,relative_humidity_2m_mean'
    : 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,relative_humidity_2m_mean';
  const host = archive ? 'https://archive-api.open-meteo.com/v1/archive' : 'https://api.open-meteo.com/v1/forecast';
  const response = await fetch(
    `${host}?latitude=${place.lat}&longitude=${place.lon}&daily=${fields}&timezone=auto&start_date=${start}&end_date=${last}`,
  );
  const daily = (await response.json()).daily;
  const days = (daily?.time || [])
    .map((date, i) => ({
      date,
      max: daily.temperature_2m_max?.[i],
      min: daily.temperature_2m_min?.[i],
      rain: daily.precipitation_probability_max?.[i],
      condition: weatherCodeName(daily.weather_code?.[i], locale),
      humidity: Math.round(Number(daily.relative_humidity_2m_mean?.[i] ?? 0)),
    }))
    .filter((day) => typeof day.max === 'number')
    .map((day) => ({ ...day, min: typeof day.min === 'number' ? day.min : null, rain: typeof day.rain === 'number' ? day.rain : null }));
  if (days.length === 0) {
    return null;
  }
  const lows = days.map((day) => day.min).filter((value) => value != null);
  return {
    days,
    temperature: Math.max(...days.map((day) => day.max)),
    temperatureMin: lows.length ? Math.min(...lows) : null,
    precipitation: days.length === 1 ? days[0].rain : null,
    condition: days[0].condition,
    humidity: Math.round(days.reduce((sum, day) => sum + day.humidity, 0) / days.length),
    forDate: days[0].date,
    forEndDate: days.length > 1 ? days[days.length - 1].date : null,
    cutAfter: end > lastForecast ? lastForecast : null,
  };
}

/** Current weather when no date or only today is asked, otherwise the forecast or record of each asked day. */
async function readWeather(query, date, endDate, key, locale) {
  if (!key) {
    return null;
  }
  const start = validDate(date);
  let end = validDate(endDate);
  if (!start || (start === seoulToday() && (!end || end === start))) {
    return fetchWeather(query, key, locale);
  }
  if (!end || end < start) {
    end = start;
  }
  if (daysBetween(start, end) > 30) {
    end = addDays(start, 30);
  }
  return fetchDailyWeather(query, start, end, key, locale);
}

function weatherSummary(locale, city, reading) {
  const lang = lang2(locale);
  const t = (value) => `${Number(value).toFixed(1)}°C`;
  if (!reading.forDate) {
    return {
      ko: `${city} 현재 날씨: ${reading.condition}, ${t(reading.temperature)}, 습도 ${reading.humidity}%`,
      en: `${city} now: ${reading.condition}, ${t(reading.temperature)}, humidity ${reading.humidity}%`,
      ja: `${city}の現在の天気: ${reading.condition}、${t(reading.temperature)}、湿度 ${reading.humidity}%`,
    }[lang];
  }
  if (reading.forEndDate) {
    const span = `${dateLabel(reading.forDate, locale)} ~ ${dateLabel(reading.forEndDate, locale)}`;
    const cut = reading.cutAfter
      ? { ko: ` (${dateLabel(reading.cutAfter, locale)} 이후는 아직 예보가 없습니다)`, en: ` (no forecast yet after ${dateLabel(reading.cutAfter, locale)})`, ja: ` (${dateLabel(reading.cutAfter, locale)}以降はまだ予報がありません)` }[lang]
      : '';
    const low = reading.temperatureMin == null ? null : t(reading.temperatureMin);
    return {
      ko: `${city} ${span} 날씨: 기간 중 최고 ${t(reading.temperature)}${low ? ` / 최저 ${low}` : ''}${cut}`,
      en: `${city}, ${span}: highest ${t(reading.temperature)}${low ? ` / lowest ${low}` : ''}${cut}`,
      ja: `${city} ${span}の天気: 期間中の最高 ${t(reading.temperature)}${low ? ` / 最低 ${low}` : ''}${cut}`,
    }[lang];
  }
  const day = dateLabel(reading.forDate, locale);
  const low = reading.temperatureMin == null ? '' : { ko: ` / 최저 ${t(reading.temperatureMin)}`, en: ` / low ${t(reading.temperatureMin)}`, ja: ` / 最低 ${t(reading.temperatureMin)}` }[lang];
  const rain = reading.precipitation == null ? '' : { ko: `, 강수확률 ${reading.precipitation}%`, en: `, ${reading.precipitation}% chance of rain`, ja: `、降水確率 ${reading.precipitation}%` }[lang];
  return {
    ko: `${city} ${day} 날씨: ${reading.condition}, 최고 ${t(reading.temperature)}${low}${rain}, 습도 ${reading.humidity}%`,
    en: `${city} on ${day}: ${reading.condition}, high ${t(reading.temperature)}${low}${rain}, humidity ${reading.humidity}%`,
    ja: `${city} ${day}の天気: ${reading.condition}、最高 ${t(reading.temperature)}${low}${rain}、湿度 ${reading.humidity}%`,
  }[lang];
}

const weatherHeaders = {
  ko: ['날짜', '날씨', '최고', '최저', '강수확률', '습도'],
  en: ['Date', 'Weather', 'High', 'Low', 'Rain', 'Humidity'],
  ja: ['日付', '天気', '最高', '最低', '降水確率', '湿度'],
};

/** A day-by-day table and a line chart of the highs when more than one day was asked. */
function weatherDetails(locale, reading) {
  if (!reading.forEndDate) {
    return { table: null, chart: null };
  }
  const days = reading.days;
  return {
    table: {
      headers: weatherHeaders[lang2(locale)],
      rows: days.map((day) => [
        dateLabel(day.date, locale),
        day.condition,
        `${day.max.toFixed(1)}°C`,
        day.min == null ? '-' : `${day.min.toFixed(1)}°C`,
        day.rain == null ? '-' : `${day.rain}%`,
        `${day.humidity}%`,
      ]),
    },
    chart: { hasChart: true, type: 'line', labels: days.map((day) => day.date.slice(5).replace('-', '/')), values: days.map((day) => day.max) },
  };
}

async function storeWeather(uid, cityName, reading, retentionMs) {
  const now = new Date();
  const expire = new Date(now.getTime() + retentionMs);
  const ref = userCol(uid, 'weather_logs').doc();
  const data = {
    uid,
    cityName,
    temperature: reading.temperature,
    temperatureMin: reading.temperatureMin ?? null,
    condition: reading.condition,
    humidity: reading.humidity,
    forDate: reading.forDate || null,
    forEndDate: reading.forEndDate || null,
    searchedAt: Timestamp.fromDate(now),
    expireAt: Timestamp.fromDate(expire),
  };
  await ref.set(data);
  await audit(uid, 'create', ref.id, ['cityName', 'temperature', 'condition', 'humidity', 'forDate', 'expireAt']);
  return {
    id: ref.id,
    ...data,
    searchedAt: now.toISOString(),
    expireAt: expire.toISOString(),
  };
}

async function fetchRate(code, key) {
  const response = await fetch(`https://v6.exchangerate-api.com/v6/${key}/pair/${code}/KRW`);
  const body = await response.json();
  if (body.result !== 'success' || typeof body.conversion_rate !== 'number') {
    return null;
  }
  return body.conversion_rate;
}

/**
 * KRW per one unit of `code`: the live rate for today or no date, the European Central Bank reference rate for a past
 * date (its `date` is the business day actually quoted), and null for a future date.
 */
async function readRate(code, date, key) {
  const day = validDate(date);
  const today = seoulToday();
  if (!day || day === today) {
    const rate = key ? await fetchRate(code, key) : null;
    return rate == null ? null : { rate, date: null };
  }
  if (day > today) {
    return null;
  }
  const response = await fetch(`https://api.frankfurter.dev/v1/${day}?base=${code}&symbols=KRW`);
  const body = await response.json();
  const rate = body?.rates?.KRW;
  return typeof rate === 'number' ? { rate, date: String(body.date || day), asked: day } : null;
}

function rateSummary(locale, code, quote) {
  const lang = lang2(locale);
  const unit = code === 'JPY' ? 100 : 1;
  const value = (quote.rate * unit).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const pair = `${unit} ${code} = ${value} KRW`;
  if (!quote.date) {
    return { ko: `현재 환율: ${pair}`, en: `Current rate: ${pair}`, ja: `現在のレート: ${pair}` }[lang];
  }
  const day = dateLabel(quote.date, locale);
  const shifted = quote.date !== quote.asked
    ? { ko: ` (${dateLabel(quote.asked, locale)}은 고시일이 아니어서 직전 영업일 기준)`, en: ` (${dateLabel(quote.asked, locale)} had no fixing, so the previous business day)`, ja: ` (${dateLabel(quote.asked, locale)}は公示日でないため直前の営業日)` }[lang]
    : '';
  return {
    ko: `${day} 기준 환율: ${pair}${shifted} · 유럽중앙은행 기준환율`,
    en: `Rate on ${day}: ${pair}${shifted} · European Central Bank reference rate`,
    ja: `${day}のレート: ${pair}${shifted} · 欧州中央銀行の参照レート`,
  }[lang];
}

async function storeRate(uid, label, code, rate, retentionMs, rateDate = null) {
  const now = new Date();
  const expire = new Date(now.getTime() + retentionMs);
  const ref = userCol(uid, 'exchange_logs').doc();
  const data = {
    uid,
    currencyLabel: label,
    currencyCode: code,
    rateToKrw: rate,
    ratePerHundred: code === 'JPY' ? rate * 100 : null,
    rateDate,
    searchedAt: Timestamp.fromDate(now),
    expireAt: Timestamp.fromDate(expire),
  };
  await ref.set(data);
  await audit(uid, 'create', ref.id, ['currencyCode', 'rateToKrw', 'rateDate', 'expireAt']);
  return {
    id: ref.id,
    ...data,
    searchedAt: now.toISOString(),
    expireAt: expire.toISOString(),
  };
}

function stripHtml(value) {
  return String(value || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

async function fetchRss(country) {
  const url = country === 'JAPAN'
    ? 'https://news.google.com/rss?hl=ja&gl=JP&ceid=JP:ja'
    : 'https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en';
  const response = await fetch(url);
  if (!response.ok) {
    throw new HttpsError('unavailable', 'news-failed');
  }
  const xml = await response.text();
  const parser = new XMLParser({
    ignoreAttributes: false,
    processEntities: {
      enabled: true,
      maxTotalExpansions: 50000,
      maxExpandedLength: 1000000,
    },
  });
  const parsed = parser.parse(xml);
  let items = parsed?.rss?.channel?.item || [];
  if (!Array.isArray(items)) {
    items = [items];
  }
  return items.slice(0, 8).map((item) => {
    const title = stripHtml(item.title);
    const sourceSplit = title.split(' - ');
    const source = sourceSplit.length > 1 ? sourceSplit.pop() : 'Google News';
    return {
      title: sourceSplit.join(' - ') || title,
      summary: stripHtml(item.description).slice(0, 400),
      source,
      link: String(item.link || item.guid || title),
      publishedAt: item.pubDate ? new Date(item.pubDate) : new Date(),
    };
  }).filter((item) => item.title);
}

async function storeNews(uid, country) {
  const fetched = await fetchRss(country);
  const existing = await userCol(uid, 'news_items').get();
  const links = new Set(existing.docs.map((doc) => doc.data().link));
  const created = [];
  for (const item of fetched) {
    if (links.has(item.link) || created.length >= 5) {
      continue;
    }
    links.add(item.link);
    const ref = userCol(uid, 'news_items').doc();
    const published = Number.isNaN(item.publishedAt.getTime()) ? new Date() : item.publishedAt;
    await ref.set({
      uid,
      country,
      title: item.title,
      summary: item.summary,
      source: item.source,
      link: item.link,
      publishedAt: Timestamp.fromDate(published),
      scriptKo: null,
      createdAt: Timestamp.fromDate(new Date()),
    });
    await audit(uid, 'create', ref.id, ['country', 'title', 'source', 'link']);
    created.push(ref.id);
  }
  return created.length;
}

function geminiKey() {
  return readSecret(geminiApiKey);
}

function geminiModel() {
  return process.env.GEMINI_MODEL || 'gemini-3.8-flash';
}

async function commitDeletes(refs) {
  let batch = db().batch();
  let count = 0;
  for (const ref of refs) {
    batch.delete(ref);
    count += 1;
    if (count === 400) {
      await batch.commit();
      batch = db().batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
}

const responseSchema = {
  type: 'OBJECT',
  properties: {
    targetMenu: { type: 'STRING', format: 'enum', enum: ['schedule', 'balance', 'weather', 'exchange', 'news', 'calculator', 'general'] },
    saveMode: { type: 'STRING', format: 'enum', enum: ['auto', 'confirm', 'none'] },
    summaryText: { type: 'STRING' },
    table: {
      type: 'OBJECT',
      properties: {
        headers: { type: 'ARRAY', items: { type: 'STRING' } },
        rows: { type: 'ARRAY', items: { type: 'ARRAY', items: { type: 'STRING' } } },
      },
    },
    chart: {
      type: 'OBJECT',
      properties: {
        hasChart: { type: 'BOOLEAN' },
        type: { type: 'STRING' },
        labels: { type: 'ARRAY', items: { type: 'STRING' } },
        values: { type: 'ARRAY', items: { type: 'NUMBER' } },
      },
    },
    // Times are required and written before labels: a rambling title otherwise swallows the rest and the model skips startAt.
    balances: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          action: { type: 'STRING', format: 'enum', enum: ['create', 'update', 'delete'] },
          targetId: { type: 'STRING' },
          amount: { type: 'INTEGER' },
          isIncome: { type: 'BOOLEAN' },
          occurredAt: { type: 'STRING' },
          description: { type: 'STRING' },
        },
        required: ['action', 'amount'],
        propertyOrdering: ['action', 'targetId', 'amount', 'isIncome', 'occurredAt', 'description'],
      },
    },
    schedule: {
      type: 'OBJECT',
      properties: {
        action: { type: 'STRING', format: 'enum', enum: ['create', 'reschedule', 'cancel'] },
        targetId: { type: 'STRING' },
        startAt: { type: 'STRING' },
        endAt: { type: 'STRING' },
        allDay: { type: 'BOOLEAN' },
        title: { type: 'STRING' },
      },
      required: ['action', 'startAt'],
      propertyOrdering: ['action', 'targetId', 'startAt', 'endAt', 'allDay', 'title'],
    },
    weather: {
      type: 'OBJECT',
      properties: {
        cityQuery: { type: 'STRING' },
        cityName: { type: 'STRING' },
        date: { type: 'STRING' },
        endDate: { type: 'STRING' },
      },
    },
    exchange: { type: 'OBJECT', properties: { currencyCode: { type: 'STRING' }, date: { type: 'STRING' } } },
    news: { type: 'OBJECT', properties: { country: { type: 'STRING' } } },
    extractedSchedules: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          title: { type: 'STRING' },
          startAt: { type: 'STRING' },
          endAt: { type: 'STRING' },
          allDay: { type: 'BOOLEAN' },
        },
      },
    },
    extractedBalances: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          description: { type: 'STRING' },
          amount: { type: 'INTEGER' },
          isIncome: { type: 'BOOLEAN' },
          occurredAt: { type: 'STRING' },
        },
      },
    },
  },
  // balances is required (empty when no money is mentioned) because the model otherwise drops it whenever it picks another menu.
  required: ['targetMenu', 'saveMode', 'summaryText', 'balances'],
};

async function askGemini(locale, source, text, documentText, schedules, ledger) {
  const key = geminiKey();
  if (!key) {
    throw new HttpsError('failed-precondition', 'gemini-missing');
  }
  const model = geminiModel();
  const now = new Date();
  const weekday = new Intl.DateTimeFormat('en-US', { weekday: 'long', timeZone: 'Asia/Seoul' }).format(now);
  const prompt = [
    'You route a personal work assistant. Return only JSON for the schema.',
    `Write summaryText in locale ${locale}.`,
    `Now in Asia/Seoul: ${seoulIso(now)} (${weekday}). Resolve relative dates such as tomorrow or the day after tomorrow from this.`,
    'saveMode auto only for one clear schedule, clearly stated income or expense entries, or a weather, exchange, or news lookup.',
    'Moving, cancelling, correcting, or removing an existing schedule or ledger entry listed below is also saveMode auto.',
    'If source is file and you find schedules or amounts, saveMode must be confirm. Do not invent weather, rates, or headlines.',
    'For targetMenu weather set weather.cityQuery to the place in English as "City,CC" (default "Seoul,KR" when no place is named),',
    'weather.cityName to that place in the user\'s language, and weather.date to the asked day as YYYY-MM-DD resolved from now',
    '(e.g. 사흘 뒤 is three days after today), or empty for right now or today. When the user asks about a span of days',
    '(다음주, 이번 주, 주말, 일주일, N일간, from one day to another) set weather.date to its first day and weather.endDate to its last',
    'day: 다음주 is next Monday to next Sunday, 이번 주말 is this Saturday and Sunday, 앞으로 일주일 is today through six days later.',
    'Leave weather.endDate empty for a single day.',
    'For targetMenu exchange set exchange.currencyCode to the ISO code of the foreign currency against KRW (원달러 means USD),',
    'and exchange.date to the asked day as YYYY-MM-DD, or empty for now or today; a month and day without a year means the most',
    'recent such day that is not in the future.',
    'Schedule times use ISO-8601. A date without a time means 09:00-10:00 Asia/Seoul.',
    'For targetMenu schedule set schedule.action: create for a new event; reschedule when the user moves an existing event to another date or time;',
    'cancel when the user says an existing event is cancelled or called off. For reschedule and cancel, schedule.targetId must be the id of the',
    'existing schedule below that the user means. For create and reschedule always fill schedule.startAt with the full new ISO-8601 date and time',
    '(for reschedule resolve weekdays and dates from now; keep the old time if only the date changes, keep the old date if only the time changes),',
    'and for create fill schedule.title with only the event name in a few words, never notes, reasoning, or the rest of the message.',
    'Balance amount is a positive integer KRW.',
    'Whenever the user states income or expenses, whatever targetMenu is, put one item in balances per income or expense, with action create; money spent or paid is',
    'isIncome false, money received is isIncome true; occurredAt is when it happened, or now if not said. Use action update with targetId',
    'when the user corrects an existing ledger entry below, and action delete with targetId when they ask to remove one. For update and delete',
    'copy targetId exactly from the first column below and set description to that entry\'s description; update also carries the corrected',
    'amount, isIncome, or occurredAt. For reschedule and cancel likewise copy targetId exactly and leave schedule.title empty.',
    'If one message asks for a schedule and also states income or expenses, set targetMenu schedule and saveMode auto, put only the event in',
    'schedule, and also put every income or expense in balances; never drop the balances.',
    `existing schedules (id | title | start | state):\n${schedules || '(none)'}`,
    `existing ledger entries (id | description | kind | amount | when):\n${ledger || '(none)'}`,
    `source: ${source}`,
    `user: ${text || ''}`,
    `document: ${(documentText || '').slice(0, 30000)}`,
  ].join('\n');

  async function call(includeThinking) {
    const generationConfig = {
      responseMimeType: 'application/json',
      responseSchema,
    };
    if (includeThinking) {
      generationConfig.thinkingConfig = { thinkingLevel: 'low' };
    }
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': key,
        },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig,
        }),
      },
    );
    const body = await response.json();
    if (!response.ok) {
      return { ok: false, body };
    }
    const parts = body.candidates?.[0]?.content?.parts || [];
    const raw = parts.filter((part) => part.thought !== true).map((part) => part.text || '').join('');
    return { ok: true, raw };
  }

  let result = await call(true);
  if (!result.ok) {
    result = await call(false);
  }
  if (!result.ok || !result.raw) {
    throw new HttpsError('unavailable', 'gemini-failed');
  }
  try {
    const raw = result.raw.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    return JSON.parse(raw);
  } catch (_) {
    throw new HttpsError('unavailable', 'gemini-failed');
  }
}

const sourcesLabel = { ko: '출처', en: 'Sources', ja: '出典' };

function plainText(value) {
  return String(value || '')
    .replace(/\*\*(.+?)\*\*/g, '$1')
    .replace(/^#{1,6}\s+/gm, '')
    .replace(/^\s*[*-]\s+/gm, '• ')
    .trim();
}

/** Answers with Gemini grounded in Google Search; returns null when the call fails so the caller keeps its own answer. */
async function askWeb(locale, text, schedules, ledger) {
  const key = geminiKey();
  if (!key || !String(text || '').trim()) {
    return null;
  }
  const now = new Date();
  const weekday = new Intl.DateTimeFormat('en-US', { weekday: 'long', timeZone: 'Asia/Seoul' }).format(now);
  const prompt = [
    `Answer in locale ${locale}, in plain text without Markdown, concisely and with the concrete figures, names, and dates asked for.`,
    `Now in Asia/Seoul: ${seoulIso(now)} (${weekday}). Resolve relative dates from this.`,
    'Search the web for anything that may have changed or that you are not certain of, and answer from what you find.',
    'When a place is needed and none is named, assume Seoul, South Korea. If the answer cannot be known, say so plainly.',
    'Answer exactly what is asked: every day of an asked period, every item of an asked list, the asked date rather than today.',
    'For questions about the user\'s own plans or money, use their schedules and ledger entries below.',
    `user's schedules (id | title | start | state):\n${schedules || '(none)'}`,
    `user's ledger entries (id | description | kind | amount | when):\n${ledger || '(none)'}`,
    `question: ${text}`,
  ].join('\n');
  try {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${geminiModel()}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        tools: [{ google_search: {} }],
        generationConfig: { thinkingConfig: { thinkingLevel: 'low' } },
      }),
    });
    const body = await response.json();
    if (!response.ok) {
      console.warn('web answer failed', response.status);
      return null;
    }
    const candidate = body.candidates?.[0];
    const answer = plainText((candidate?.content?.parts || []).filter((part) => part.thought !== true).map((part) => part.text || '').join(''));
    if (!answer) {
      return null;
    }
    const sources = [...new Set((candidate.groundingMetadata?.groundingChunks || []).map((chunk) => chunk.web?.title).filter(Boolean))].slice(0, 3);
    return sources.length ? `${answer}\n${sourcesLabel[lang2(locale)]}: ${sources.join(', ')}` : answer;
  } catch (error) {
    console.warn('web answer failed', error.message);
    return null;
  }
}

async function writeTurn(uid, turn) {
  const ref = userCol(uid, 'turns').doc();
  const data = {
    uid,
    userText: String(turn.userText || '').slice(0, 4000),
    aiText: String(turn.aiText || '').slice(0, 8000),
    isVoice: turn.isVoice === true,
    fileName: turn.fileName || null,
    table: turn.table || null,
    chart: turn.chart && turn.chart.hasChart !== false ? turn.chart : null,
    savedMenu: turn.savedMenu || null,
    targetMenu: ['schedules', 'balance', 'weather', 'exchange', 'news', 'calculator'].includes(turn.targetMenu)
      ? turn.targetMenu
      : null,
    awaitingConfirm: turn.awaitingConfirm === true,
    extractedSchedules: turn.extractedSchedules || [],
    extractedBalances: turn.extractedBalances || [],
    createdAt: Timestamp.fromDate(new Date()),
  };
  await ref.set(data);
  return { id: ref.id, ...data, createdAt: new Date().toISOString() };
}

async function extractText(fileName, buffer) {
  const ext = String(fileName || '').split('.').pop().toLowerCase();
  if (['doc', 'xls', 'ppt'].includes(ext)) {
    throw new HttpsError('failed-precondition', 'legacy-office');
  }
  if (ext === 'txt') {
    return buffer.toString('utf8');
  }
  if (ext === 'pdf') {
    const pdfParse = require('pdf-parse');
    const parsed = await pdfParse(buffer);
    return parsed.text || '';
  }
  if (ext === 'docx') {
    const mammoth = require('mammoth');
    const parsed = await mammoth.extractRawText({ buffer });
    return parsed.value || '';
  }
  if (ext === 'xlsx') {
    const ExcelJS = require('exceljs');
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(buffer);
    const lines = [];
    workbook.eachSheet((sheet) => {
      sheet.eachRow((row) => {
        const values = Array.isArray(row.values) ? row.values.filter((value) => value != null) : [];
        lines.push(values.map((value) => String(value)).join('\t'));
      });
    });
    return lines.join('\n');
  }
  if (ext === 'pptx') {
    const JSZip = require('jszip');
    const zip = await JSZip.loadAsync(buffer);
    const names = Object.keys(zip.files).filter((name) => /ppt\/slides\/slide\d+\.xml/.test(name));
    const chunks = [];
    for (const name of names) {
      const xml = await zip.files[name].async('string');
      chunks.push(stripHtml(xml));
    }
    return chunks.join('\n');
  }
  throw new HttpsError('invalid-argument', 'bad-extension');
}

async function applyIntent(uid, intent, localeLabel, retentionMs) {
  const menu = ['schedule', 'balance', 'weather', 'exchange', 'news', 'calculator', 'general'].includes(intent.targetMenu)
    ? intent.targetMenu
    : 'general';
  let mode = ['auto', 'confirm', 'none'].includes(intent.saveMode) ? intent.saveMode : 'none';
  if (menu === 'general' || menu === 'calculator') {
    mode = 'none';
  }
  const extractedSchedules = Array.isArray(intent.extractedSchedules) ? intent.extractedSchedules : [];
  const extractedBalances = Array.isArray(intent.extractedBalances) ? intent.extractedBalances : [];
  let savedMenu = null;
  let summary = String(intent.summaryText || '');
  let chart = intent.chart && intent.chart.hasChart ? intent.chart : null;
  let table = intent.table || null;

  // One message may carry a schedule and ledger entries together; `failed` marks any part that could not be applied.
  let failed = false;
  const draft = intent.schedule || {};
  const changes = Array.isArray(intent.balances) ? intent.balances : intent.balance ? [intent.balance] : [];
  const wantsSchedule = menu === 'schedule' || (menu === 'balance' && Boolean(draft.title && draft.startAt));
  const wantsBalance = menu === 'balance' || (menu === 'schedule' && changes.length > 0);
  if (mode === 'auto' && wantsSchedule) {
    const id = draft.action === 'cancel'
      ? await cancelSchedule(uid, draft.targetId, draft.title)
      : draft.action === 'reschedule'
        ? await rescheduleSchedule(uid, draft.targetId, draft)
        : await saveSchedule(uid, draft);
    if (id) {
      savedMenu = 'schedules';
    } else {
      console.warn('schedule not applied', { action: draft.action || 'create', hasTarget: Boolean(draft.targetId), hasStart: Boolean(draft.startAt) });
      failed = true;
    }
  }
  if (mode === 'auto' && wantsBalance) {
    const applied = await applyBalanceChanges(uid, changes);
    if (applied > 0) {
      savedMenu = savedMenu || 'balance';
    } else {
      console.warn('balance not applied', { actions: changes.map((change) => change?.action || 'create') });
      failed = true;
    }
  }
  if (failed && !savedMenu) {
    mode = 'none';
  }
  if (menu === 'weather') {
    const query = resolveCityQuery(intent.weather?.cityQuery || '');
    const city = String(intent.weather?.cityName || '').trim() || query;
    const reading = await readWeather(query, intent.weather?.date, intent.weather?.endDate, readSecret(openWeatherKey), localeLabel);
    if (reading) {
      const stored = await storeWeather(uid, city, reading, retentionMs);
      summary = weatherSummary(localeLabel, city, reading);
      const details = weatherDetails(localeLabel, reading);
      table = details.table;
      chart = reading.forDate
        ? details.chart
        : { hasChart: true, type: 'bar', labels: [stored.cityName], values: [stored.temperature] };
      savedMenu = 'weather';
    }
  }
  if (menu === 'exchange') {
    const code = String(intent.exchange?.currencyCode || '').toUpperCase();
    const quote = /^[A-Z]{3}$/.test(code) && code !== 'KRW'
      ? await readRate(code, intent.exchange?.date, readSecret(exchangeKey))
      : null;
    if (quote) {
      await storeRate(uid, code, code, quote.rate, retentionMs, quote.date);
      summary = rateSummary(localeLabel, code, quote);
      table = null;
      chart = null;
      savedMenu = 'exchange';
    }
  }
  if (mode === 'auto' && menu === 'news') {
    const country = String(intent.news?.country || '').toUpperCase() === 'JAPAN' ? 'JAPAN' : 'USA';
    const count = await storeNews(uid, country);
    summary = `${country} ${count}`;
    chart = null;
    savedMenu = 'news';
  }

  const awaitingConfirm = mode === 'confirm' && (extractedSchedules.length > 0 || extractedBalances.length > 0);
  return {
    aiText: summary,
    table,
    chart,
    savedMenu,
    targetMenu: menu === 'general' ? null : menu === 'schedule' ? 'schedules' : menu,
    awaitingConfirm,
    extractedSchedules: awaitingConfirm ? extractedSchedules : [],
    extractedBalances: awaitingConfirm ? extractedBalances : [],
    localeLabel,
    failed,
    // Every answer that is not a saved change or a weather, rate, or news lookup is written by the web-searching model.
    askWeb: !savedMenu && !failed && !awaitingConfirm,
  };
}

const notAppliedText = {
  ko: '요청하신 변경을 적용하지 못했습니다. 일정이나 내역의 이름과 날짜·시간을 조금 더 구체적으로 말씀해 주세요.',
  en: 'I could not apply that change. Please name the item and its date and time a little more specifically.',
  ja: '変更を反映できませんでした。予定や項目の名前と日時をもう少し具体的に教えてください。',
};

const partlyAppliedText = {
  ko: '(일부 항목은 적용하지 못했습니다. 빠진 항목을 다시 말씀해 주세요.)',
  en: '(Some items could not be applied. Please say the missing ones again.)',
  ja: '(一部の項目は反映できませんでした。抜けた項目をもう一度お伝えください。)',
};

async function loadUpload(uid, filePath) {
  if (!filePath.startsWith(`uploads/${uid}/`)) {
    throw new HttpsError('permission-denied', 'bad-path');
  }
  const file = getStorage().bucket().file(filePath);
  const [metadata] = await file.getMetadata();
  if (Number(metadata.size || 0) > 20 * 1024 * 1024) {
    await file.delete({ ignoreNotFound: true });
    throw new HttpsError('invalid-argument', 'file-too-large');
  }
  const [buffer] = await file.download();
  return { file, buffer };
}

exports.getWeather = onCall({ region, secrets: [openWeatherKey] }, async (request) => {
  const uid = requireUid(request);
  await purgeExpired(uid, 'weather_logs');
  const cityName = String(request.data.cityName || '').trim();
  const cityQuery = resolveCityQuery(request.data.cityQuery || cityName);
  const reading = await fetchWeather(cityQuery, readSecret(openWeatherKey));
  if (!reading) {
    throw new HttpsError('not-found', 'city-not-found');
  }
  return storeWeather(uid, cityName || cityQuery, reading, retentionFor(request));
});

exports.getExchange = onCall({ region, secrets: [exchangeKey] }, async (request) => {
  const uid = requireUid(request);
  await purgeExpired(uid, 'exchange_logs');
  const code = String(request.data.currencyCode || '').toUpperCase();
  const label = String(request.data.currencyLabel || code);
  const allowed = ['USD', 'JPY', 'EUR', 'CNY', 'SGD', 'MYR'];
  if (!allowed.includes(code)) {
    throw new HttpsError('invalid-argument', 'bad-currency');
  }
  const rate = await fetchRate(code, readSecret(exchangeKey));
  if (rate == null) {
    throw new HttpsError('unavailable', 'rate-failed');
  }
  return storeRate(uid, label, code, rate, retentionFor(request));
});

function newsPayload(id, data) {
  const published = data.publishedAt?.toDate ? data.publishedAt.toDate() : new Date();
  return {
    id,
    country: data.country,
    title: data.title,
    summary: data.summary,
    source: data.source,
    link: data.link,
    publishedAt: published.toISOString(),
    scriptKo: data.scriptKo || data.scriptText || null,
  };
}

async function recentNews(uid, country) {
  const snap = await userCol(uid, 'news_items').orderBy('publishedAt', 'desc').get();
  return snap.docs
    .filter((doc) => doc.data().country === country)
    .slice(0, 5)
    .map((doc) => newsPayload(doc.id, doc.data()));
}

exports.getNews = onCall({ region, invoker: 'public' }, async (request) => {
  const uid = requireUid(request);
  const country = String(request.data.country || '').toUpperCase() === 'JAPAN' ? 'JAPAN' : 'USA';
  const count = await storeNews(uid, country);
  const items = await recentNews(uid, country);
  return { count, items };
});

exports.deleteByIds = onCall({ region }, async (request) => {
  const uid = requireUid(request);
  const collection = String(request.data.collection || '');
  const allowed = ['schedules', 'balance_entries', 'news_items', 'weather_logs', 'exchange_logs', 'turns'];
  if (!allowed.includes(collection)) {
    throw new HttpsError('invalid-argument', 'bad-collection');
  }
  const ids = Array.isArray(request.data.ids) ? request.data.ids.map(String) : [];
  if (ids.length === 0) {
    throw new HttpsError('invalid-argument', 'bad-ids');
  }
  let batch = db().batch();
  let count = 0;
  for (const id of ids) {
    batch.delete(userCol(uid, collection).doc(id));
    count += 1;
    if (count === 400) {
      await batch.commit();
      batch = db().batch();
      count = 0;
    }
  }
  if (count > 0) {
    await batch.commit();
  }
  if (collection === 'balance_entries') {
    await recalculateBalances(uid);
  }
  await audit(uid, 'delete', ids[0], ['id']);
  return { deleted: ids.length };
});

/** Hides the prompt or the answer of chat turns; a turn with both halves gone is deleted. */
exports.hideTurnParts = onCall({ region }, async (request) => {
  const uid = requireUid(request);
  const parts = Array.isArray(request.data.parts) ? request.data.parts.slice(0, 400) : [];
  const wanted = parts
    .map((part) => ({ id: String(part?.id || ''), user: part?.user === true, ai: part?.ai === true }))
    .filter((part) => part.id && !part.id.includes('/') && (part.user || part.ai));
  if (wanted.length === 0) {
    throw new HttpsError('invalid-argument', 'bad-parts');
  }
  const refs = wanted.map((part) => userCol(uid, 'turns').doc(part.id));
  const snaps = await db().getAll(...refs);
  const batch = db().batch();
  let deleted = 0;
  snaps.forEach((snap, index) => {
    if (!snap.exists) {
      return;
    }
    const part = wanted[index];
    const userHidden = part.user || snap.get('userHidden') === true;
    const aiHidden = part.ai || snap.get('aiHidden') === true;
    if (userHidden && aiHidden) {
      batch.delete(snap.ref);
      deleted += 1;
    } else {
      batch.update(snap.ref, { userHidden, aiHidden });
    }
  });
  await batch.commit();
  await audit(uid, 'hide-turn-parts', wanted[0].id, ['userHidden', 'aiHidden']);
  return { updated: wanted.length - deleted, deleted };
});

exports.appendTurn = onCall({ region }, async (request) => {
  const uid = requireUid(request);
  const turn = request.data.turn || {};
  const saved = await writeTurn(uid, turn);
  return { turn: saved };
});

exports.submitPrompt = onCall({ region, secrets: [openWeatherKey, exchangeKey, geminiApiKey], timeoutSeconds: 120, memory: '512MiB' }, async (request) => {
  const uid = requireUid(request);
  const text = String(request.data.text || '');
  const locale = String(request.data.locale || 'ko');
  const filePath = request.data.filePath ? String(request.data.filePath) : '';
  const fileName = request.data.fileName ? String(request.data.fileName) : '';
  let documentText = '';
  let uploaded = null;
  let extracted = false;
  try {
    if (filePath) {
      uploaded = await loadUpload(uid, filePath);
      documentText = await extractText(fileName, uploaded.buffer);
      extracted = true;
    }
    const [schedules, ledger] = await Promise.all([scheduleContext(uid), balanceContext(uid)]);
    const intent = await askGemini(locale, filePath ? 'file' : 'text', text, documentText, schedules, ledger);
    if (filePath && ((intent.extractedSchedules || []).length || (intent.extractedBalances || []).length)) {
      intent.saveMode = 'confirm';
    }
    const retentionMs = retentionFor(request);
    let applied = await applyIntent(uid, intent, locale, retentionMs);
    // The model occasionally drops a time or garbles a title; nothing was saved, so asking once more cannot duplicate anything.
    if (applied.failed && !applied.savedMenu && !filePath) {
      applied = await applyIntent(uid, await askGemini(locale, 'text', text, '', schedules, ledger), locale, retentionMs);
    }
    if (applied.askWeb && !filePath) {
      const answer = await askWeb(locale, text, schedules, ledger);
      if (answer) {
        applied.aiText = answer;
        // Tables and charts the router built from the user's own data stay; others could contradict the searched answer.
        if (!['schedules', 'balance', 'calculator'].includes(applied.targetMenu)) {
          applied.table = null;
          applied.chart = null;
        }
      }
    }
    if (applied.failed) {
      const lang = notAppliedText[locale.slice(0, 2)] ? locale.slice(0, 2) : 'ko';
      if (applied.savedMenu) {
        applied.aiText = `${applied.aiText}\n${partlyAppliedText[lang]}`;
      } else {
        applied.aiText = notAppliedText[lang];
        applied.table = null;
        applied.chart = null;
      }
    }
    const turn = await writeTurn(uid, {
      userText: text || fileName,
      isVoice: request.data.isVoice === true,
      fileName: fileName || null,
      ...applied,
    });
    return { turn };
  } catch (error) {
    if (uploaded && !extracted) {
      await uploaded.file.delete({ ignoreNotFound: true });
    }
    if (error instanceof HttpsError) {
      throw error;
    }
    throw new HttpsError('internal', 'save-failed');
  }
});

exports.confirmExtracted = onCall({ region }, async (request) => {
  const uid = requireUid(request);
  const turnId = String(request.data.turnId || '');
  const kind = String(request.data.kind || '');
  const ref = userCol(uid, 'turns').doc(turnId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'missing-turn');
  }
  const data = snap.data();
  let savedMenu = data.savedMenu || null;
  if (kind === 'schedules') {
    for (const item of data.extractedSchedules || []) {
      const id = await saveSchedule(uid, item);
      if (id) {
        savedMenu = 'schedules';
      }
    }
    data.extractedSchedules = [];
  }
  if (kind === 'balances') {
    for (const item of data.extractedBalances || []) {
      const id = await saveBalance(uid, item);
      if (id) {
        savedMenu = 'balance';
      }
    }
    data.extractedBalances = [];
  }
  const awaitingConfirm = (data.extractedSchedules || []).length + (data.extractedBalances || []).length > 0;
  await ref.update({
    extractedSchedules: data.extractedSchedules || [],
    extractedBalances: data.extractedBalances || [],
    awaitingConfirm,
    savedMenu,
  });
  const updated = await ref.get();
  return { turn: { id: ref.id, ...updated.data(), createdAt: new Date().toISOString() } };
});

exports.scriptNews = onCall({ region, secrets: [geminiApiKey], timeoutSeconds: 120, memory: '512MiB' }, async (request) => {
  const uid = requireUid(request);
  const newsId = String(request.data.newsId || '');
  const ref = userCol(uid, 'news_items').doc(newsId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'missing-news');
  }
  const news = snap.data();
  const intent = await askGemini(
    'ko',
    'text',
    `Summarize this news article in Korean. targetMenu general, saveMode none.\n${news.title}\n${news.summary}`,
    '',
  );
  const scriptKo = String(intent.summaryText || news.summary || '');
  await ref.update({ scriptKo });
  await audit(uid, 'update', newsId, ['scriptKo']);
  const turn = await writeTurn(uid, {
    userText: news.title,
    aiText: scriptKo,
    savedMenu: null,
    targetMenu: 'news',
  });
  return { scriptKo, turn };
});

exports.withdraw = onCall({ region, timeoutSeconds: 120 }, async (request) => {
  const uid = requireUid(request);
  const names = ['schedules', 'balance_entries', 'news_items', 'weather_logs', 'exchange_logs', 'turns'];
  for (const name of names) {
    const snap = await userCol(uid, name).get();
    await commitDeletes(snap.docs.map((doc) => doc.ref));
  }
  const audits = await db().collection('audit').where('actorUid', '==', uid).get();
  await commitDeletes(audits.docs.map((doc) => doc.ref));
  const [files] = await getStorage().bucket().getFiles({ prefix: `uploads/${uid}/` });
  await Promise.all(files.map((file) => file.delete({ ignoreNotFound: true })));
  await db().collection('users').doc(uid).delete().catch(() => undefined);
  await backupDb().recursiveDelete(backupDb().collection('users').doc(uid)).catch(() => undefined);
  await getAuth().deleteUser(uid);
  return { ok: true };
});

exports.mirrorToBackup = onDocumentWritten(
  { region, database: databaseId, document: 'users/{uid}/{collection}/{docId}' },
  async (event) => {
    const { uid, collection, docId } = event.params;
    if (!mirroredCollections.includes(collection)) {
      return;
    }
    const target = backupCol(uid, collection).doc(docId);
    const after = event.data && event.data.after;
    const eventMs = Date.parse(event.time);
    await backupDb().runTransaction(async (tx) => {
      const current = await tx.get(target);
      const seenMs = current.exists ? Date.parse(current.get('mirrorEventTime') || '') : NaN;
      if (!Number.isNaN(seenMs) && seenMs > eventMs) {
        return;
      }
      if (!after || !after.exists) {
        tx.delete(target);
        return;
      }
      tx.set(target, { ...after.data(), mirrorEventTime: event.time, mirroredAt: Timestamp.now() });
    });
  },
);

exports.readBackup = onCall({ region }, async (request) => {
  const uid = requireUid(request);
  const collection = String(request.data.collection || '');
  if (!mirroredCollections.includes(collection)) {
    throw new HttpsError('invalid-argument', 'bad-collection');
  }
  const snap = await backupCol(uid, collection).limit(500).get();
  const now = Date.now();
  const items = snap.docs
    .map((doc) => ({ ...plain(doc.data()), id: doc.id }))
    .filter((item) => !item.expireAt || Date.parse(item.expireAt) > now);
  return { items };
});

async function describeStore(database, uid) {
  try {
    const user = database.collection('users').doc(uid);
    const counts = await Promise.all(
      mirroredCollections.map((name) => user.collection(name).count().get()),
    );
    const total = counts.reduce((sum, agg) => sum + agg.data().count, 0);
    let lastMirroredAt = null;
    if (total > 0) {
      const latest = await Promise.all(
        mirroredCollections.map((name) => user.collection(name).orderBy('mirroredAt', 'desc').limit(1).get()),
      );
      for (const snap of latest) {
        const at = snap.empty ? null : snap.docs[0].get('mirroredAt');
        if (at && (!lastMirroredAt || at.toMillis() > lastMirroredAt.toMillis())) {
          lastMirroredAt = at;
        }
      }
    }
    return { ok: true, total, lastMirroredAt: lastMirroredAt ? lastMirroredAt.toDate().toISOString() : null };
  } catch (error) {
    console.warn('describeStore failed', error.message);
    return { ok: false, total: 0, lastMirroredAt: null };
  }
}

exports.dbStatus = onCall({ region }, async (request) => {
  const uid = requireUid(request);
  const [primary, backup] = await Promise.all([describeStore(db(), uid), describeStore(backupDb(), uid)]);
  return { primary, backup };
});

exports.syncBackup = onCall({ region, timeoutSeconds: 300 }, async (request) => {
  const uid = requireUid(request);
  const stamp = Timestamp.now();
  let copied = 0;
  for (const name of mirroredCollections) {
    const [source, mirror] = await Promise.all([userCol(uid, name).get(), backupCol(uid, name).get()]);
    const live = new Set(source.docs.map((doc) => doc.id));
    const writer = backupDb().bulkWriter();
    for (const doc of source.docs) {
      writer.set(backupCol(uid, name).doc(doc.id), {
        ...doc.data(),
        mirrorEventTime: stamp.toDate().toISOString(),
        mirroredAt: stamp,
      });
      copied += 1;
    }
    for (const doc of mirror.docs) {
      if (!live.has(doc.id)) {
        writer.delete(doc.ref);
      }
    }
    await writer.close();
  }
  await audit(uid, 'sync-backup', uid, mirroredCollections);
  return { copied };
});

// The field each collection stamps when a document is created; retention counts from it.
const createdFields = {
  schedules: 'createdAt',
  balance_entries: 'createdAt',
  news_items: 'createdAt',
  weather_logs: 'searchedAt',
  exchange_logs: 'searchedAt',
  turns: 'createdAt',
};

// The purge runs every 10 minutes and removes whatever would pass its limit before the next run, so nothing outlives it.
const purgeLeadMs = 15 * 60 * 1000;

/**
 * Guests (anonymous accounts, or accounts already gone) keep data 72 hours, signed-in users 240 hours; see
 * `collectionRetentionMs` for schedules and ledger entries.
 */
async function retentionOf(uid) {
  try {
    const user = await getAuth().getUser(uid);
    return user.providerData.length === 0 ? guestRetentionMs : memberRetentionMs;
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      return guestRetentionMs;
    }
    throw error;
  }
}

function collectionRetentionMs(name, baseMs) {
  if (!recordCollections.includes(name)) {
    return baseMs;
  }
  return baseMs === guestRetentionMs ? guestRecordRetentionMs : memberRecordRetentionMs;
}

function createdMs(doc, field) {
  const stamp = doc.get(field);
  return stamp && typeof stamp.toMillis === 'function' ? stamp.toMillis() : doc.createTime.toMillis();
}

/**
 * Deletes one user's documents that would outlive their collection's retention before the next run. The regular pass
 * queries the creation field; the daily full pass also catches documents that lack it. Returns the names of collections
 * that lost documents.
 */
async function purgeUserData(database, uid, now, baseMs, fullScan) {
  const touched = [];
  const writer = database.bulkWriter();
  for (const [name, field] of Object.entries(createdFields)) {
    const cutoff = now - collectionRetentionMs(name, baseMs) + purgeLeadMs;
    const col = database.collection('users').doc(uid).collection(name);
    const snap = fullScan ? await col.get() : await col.where(field, '<=', Timestamp.fromMillis(cutoff)).get();
    const expired = snap.docs.filter((doc) => createdMs(doc, field) <= cutoff);
    expired.forEach((doc) => writer.delete(doc.ref));
    if (expired.length > 0) {
      touched.push(name);
    }
  }
  await writer.close();
  return touched;
}

async function purgeAudit(now, guests) {
  const writer = db().bulkWriter();
  const memberCutoff = Timestamp.fromMillis(now - memberRetentionMs + purgeLeadMs);
  const old = await db().collection('audit').where('at', '<=', memberCutoff).get();
  old.docs.forEach((doc) => writer.delete(doc.ref));
  const guestCutoff = Timestamp.fromMillis(now - guestRetentionMs + purgeLeadMs);
  for (const uid of guests) {
    const snap = await db().collection('audit').where('actorUid', '==', uid).where('at', '<=', guestCutoff).get();
    snap.docs.forEach((doc) => writer.delete(doc.ref));
  }
  await writer.close();
}

async function purgeUploads(now, retention) {
  const [files] = await getStorage().bucket().getFiles({ prefix: 'uploads/' });
  for (const file of files) {
    const uid = file.name.split('/')[1];
    if (!uid) {
      continue;
    }
    if (!retention.has(uid)) {
      retention.set(uid, await retentionOf(uid).catch(() => null));
    }
    const keepMs = retention.get(uid);
    const created = Date.parse(file.metadata.timeCreated || '');
    if (keepMs && !Number.isNaN(created) && created <= now - keepMs + purgeLeadMs) {
      await file.delete({ ignoreNotFound: true });
    }
  }
}

/** Removes every user's expired data from Firebase Firestore, the Google Cloud backup database, the audit log, and Storage. */
async function purgeRetention(now, fullScan) {
  const [primaryUsers, backupUsers] = await Promise.all([
    db().collection('users').listDocuments(),
    backupDb().collection('users').listDocuments(),
  ]);
  const uids = [...new Set([...primaryUsers, ...backupUsers].map((ref) => ref.id))];
  const retention = new Map();
  for (const uid of uids) {
    try {
      const keepMs = await retentionOf(uid);
      retention.set(uid, keepMs);
      const touched = await purgeUserData(db(), uid, now, keepMs, fullScan);
      if (touched.includes('balance_entries')) {
        await recalculateBalances(uid);
      }
      await purgeUserData(backupDb(), uid, now, keepMs, fullScan);
    } catch (error) {
      console.error('retention purge failed for a user', error.message);
    }
  }
  const guests = [...retention].filter(([, keepMs]) => keepMs === guestRetentionMs).map(([uid]) => uid);
  const results = await Promise.allSettled([purgeAudit(now, guests), purgeUploads(now, retention)]);
  const failures = results.filter((result) => result.status === 'rejected');
  if (failures.length > 0) {
    throw new Error(failures.map((result) => result.reason?.message).join('; '));
  }
}

exports.purgeExpiredData = onSchedule(
  { region, schedule: 'every 10 minutes', timeZone: 'Asia/Seoul', timeoutSeconds: 540, memory: '512MiB' },
  async () => {
    const now = Date.now();
    const seoul = new Date(now + 9 * 60 * 60 * 1000);
    await purgeRetention(now, seoul.getUTCHours() === 4 && seoul.getUTCMinutes() < 10);
  },
);
