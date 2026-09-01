// 주 계산 · 원장 · 표시 문자열. 화면과 저장에 의존하지 않는 순수 함수만 둔다.
// Swift 판(GameTimer/Core/WeekMath.swift, TimeFormat.swift)을 그대로 옮긴 것이라 규칙이 동일하다.

export const WEEKDAY_SYMBOLS = ['일', '월', '화', '수', '목', '금', '토'];

// ---------- 주 경계 ----------

export function startOfDay(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

/** `date`가 속한 주의 구간. 시작은 주 첫날 자정, 끝은 다음 주 첫날 자정(반열림). */
export function weekInterval(date, weekStart = 'monday') {
  const start = startOfDay(date);
  const dow = start.getDay(); // 0=일 … 6=토
  const offset = weekStart === 'monday' ? (dow + 6) % 7 : dow;
  start.setDate(start.getDate() - offset);
  const end = new Date(start);
  // 날짜 단위로 더하므로 서머타임이 낀 주도 정확하다(초 단위 산술 금지).
  end.setDate(end.getDate() + 7);
  return { start, end };
}

/**
 * 반열림 판정: `start <= date < end`.
 * 끝점을 포함하면 경계 자정에 찍힌 기록이 두 주에 중복 집계된다.
 */
export function intervalContains(interval, date) {
  const t = date.getTime();
  return t >= interval.start.getTime() && t < interval.end.getTime();
}

export function eventsIn(interval, events) {
  return events.filter((e) => intervalContains(interval, new Date(e.date)));
}

// ---------- 원장 ----------

export function signOf(kind) {
  return kind === 'benefit' ? 1 : -1;
}

export function signedMinutesOf(event) {
  return signOf(event.kind) * event.minutes;
}

export function netMinutes(events) {
  return events.reduce((sum, e) => sum + signedMinutesOf(e), 0);
}

export function remainingMinutes(events, weeklyBaseMinutes, now, weekStart) {
  return weeklyBaseMinutes + netMinutes(eventsIn(weekInterval(now, weekStart), events));
}

// ---------- 묶음 ----------

/** 기록을 주 → 일로 묶는다. 주/일/기록 모두 최신순. */
export function groupByWeekThenDay(events, weekStart = 'monday') {
  if (events.length === 0) return [];

  const weeks = new Map();
  for (const event of events) {
    const interval = weekInterval(new Date(event.date), weekStart);
    const key = interval.start.getTime();
    if (!weeks.has(key)) weeks.set(key, { interval, events: [] });
    weeks.get(key).events.push(event);
  }

  return [...weeks.values()]
    .sort((a, b) => b.interval.start - a.interval.start)
    .map((week) => {
      const days = new Map();
      for (const event of week.events) {
        const day = startOfDay(new Date(event.date));
        const key = day.getTime();
        if (!days.has(key)) days.set(key, { day, events: [] });
        days.get(key).events.push(event);
      }
      return {
        interval: week.interval,
        netMinutes: netMinutes(week.events),
        days: [...days.values()]
          .sort((a, b) => b.day - a.day)
          .map((d) => ({
            day: d.day,
            // 같은 시각이면 id로 순서를 고정해 렌더링이 흔들리지 않게 한다.
            events: [...d.events].sort((x, y) => {
              const diff = new Date(y.date) - new Date(x.date);
              return diff !== 0 ? diff : (y.id < x.id ? -1 : 1);
            }),
            netMinutes: netMinutes(d.events),
          })),
      };
    });
}

// ---------- 표시 문자열 ----------

function pad2(n) {
  return n < 10 ? `0${n}` : `${n}`;
}

/** 분을 `HH:MM`으로. 음수는 앞에 `-`. 예: 108 → "01:48", -150 → "-02:30". */
export function hhmm(minutes) {
  const total = Math.abs(Math.trunc(minutes));
  const sign = minutes < 0 ? '-' : '';
  return `${sign}${pad2(Math.floor(total / 60))}:${pad2(total % 60)}`;
}

export function signedLabel(signed) {
  return `${signed < 0 ? '-' : '+'}${Math.abs(signed)}분`;
}

export function netLabel(net) {
  return net === 0 ? '0분' : signedLabel(net);
}

/** 24시간제 시각. 예: "14:32". */
export function timeLabel(date) {
  const d = new Date(date);
  return `${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

/** 히스토리 일자 헤더. 예: "8월 27일 (수)". */
export function dayTitle(date) {
  const d = new Date(date);
  return `${d.getMonth() + 1}월 ${d.getDate()}일 (${WEEKDAY_SYMBOLS[d.getDay()]})`;
}

function shortDate(date) {
  const d = new Date(date);
  return `${d.getMonth() + 1}.${d.getDate()}`;
}

/** 주 구간을 "8.25 – 8.31"로. 끝은 반열림이라 하루를 빼서 마지막 날을 구한다. */
export function weekRange(interval) {
  const last = new Date(interval.end);
  last.setDate(last.getDate() - 1);
  return `${shortDate(interval.start)} – ${shortDate(last)}`;
}

/** 이번 주/지난 주는 이름으로, 그 이전은 날짜 범위로. */
export function weekTitle(interval, now, weekStart = 'monday') {
  const current = weekInterval(now, weekStart);
  if (interval.start.getTime() === current.start.getTime()) return '이번 주';
  const previous = new Date(current.start);
  previous.setDate(previous.getDate() - 7);
  if (interval.start.getTime() === previous.getTime()) return '지난 주';
  return weekRange(interval);
}

// ---------- 화면 테마 ----------

export const THEMES = ['system', 'light', 'dark', 'auto'];

/** 자동 모드에서 어둡게 유지할 시간대 (19시 ~ 다음날 7시). */
export const NIGHT_FROM = 19;
export const NIGHT_TO = 7;

/**
 * 설정값과 현재 시각으로 실제 적용할 테마를 정한다.
 * `system`일 때만 기기 설정(prefersDark)을 따른다.
 */
export function effectiveTheme(preference, now, prefersDark) {
  if (preference === 'light' || preference === 'dark') return preference;
  if (preference === 'auto') {
    const hour = new Date(now).getHours();
    return hour >= NIGHT_FROM || hour < NIGHT_TO ? 'dark' : 'light';
  }
  return prefersDark ? 'dark' : 'light';
}
