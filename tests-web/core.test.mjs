// Swift 판 Tests/LogicTests.swift 와 같은 항목을 검증한다. 실행: node tests-web/core.test.mjs
import assert from 'node:assert/strict';
import test from 'node:test';
import * as C from '../docs/core.js';

// 로컬 시간대 기준으로 날짜를 만든다(앱도 로컬 시간대로 동작한다).
const d = (y, mo, day, h = 0, mi = 0) => new Date(y, mo - 1, day, h, mi, 0, 0);
const ev = (kind, minutes, date, name = '테스트', id = `${date.getTime()}-${name}`) =>
  ({ id, kind, name, minutes, date: date.toISOString() });

const mondayAug25 = d(2025, 8, 25); // 2025-08-25는 월요일
const sundayAug31 = d(2025, 8, 31);

test('시간 표시', () => {
  assert.equal(C.hhmm(0), '00:00');
  assert.equal(C.hhmm(108), '01:48');
  assert.equal(C.hhmm(420), '07:00');
  assert.equal(C.hhmm(59), '00:59');
  assert.equal(C.hhmm(-150), '-02:30');
  assert.equal(C.hhmm(-1), '-00:01');
  assert.equal(C.hhmm(10080), '168:00');
  assert.equal(C.signedLabel(15), '+15분');
  assert.equal(C.signedLabel(-30), '-30분');
  assert.equal(C.netLabel(0), '0분');
  assert.equal(C.netLabel(-45), '-45분');
});

test('주 구간 — 월요일 시작', () => {
  const week = C.weekInterval(d(2025, 8, 27, 14, 30), 'monday');
  assert.equal(+week.start, +mondayAug25);
  assert.equal(+week.end, +d(2025, 9, 1));
  // 일요일 23:59는 같은 주, 월요일 00:00은 다음 주.
  assert.equal(+C.weekInterval(d(2025, 8, 31, 23, 59), 'monday').start, +mondayAug25);
  assert.equal(+C.weekInterval(d(2025, 9, 1), 'monday').start, +d(2025, 9, 1));
});

test('주 구간 — 일요일 시작', () => {
  const week = C.weekInterval(d(2025, 8, 27, 14, 30), 'sunday');
  assert.equal(+week.start, +d(2025, 8, 24));
  assert.equal(+week.end, +sundayAug31);
  assert.equal(+C.weekInterval(sundayAug31, 'sunday').start, +sundayAug31);
});

test('연말 경계', () => {
  const week = C.weekInterval(d(2025, 12, 31, 23, 0), 'monday');
  assert.equal(+week.start, +d(2025, 12, 29));
  assert.equal(+week.end, +d(2026, 1, 5));
  assert.equal(+C.weekInterval(d(2026, 1, 1, 9, 0), 'monday').start, +d(2025, 12, 29));
});

test('반열림 구간 — 경계 기록이 중복 집계되지 않는다', () => {
  const week = C.weekInterval(mondayAug25, 'monday');
  assert.ok(C.intervalContains(week, week.start));
  assert.ok(!C.intervalContains(week, week.end));
  assert.ok(C.intervalContains(week, new Date(+week.end - 1000)));

  const boundary = ev('penalty', 30, week.end);
  assert.equal(C.eventsIn(week, [boundary]).length, 0);
  assert.equal(C.eventsIn(C.weekInterval(week.end, 'monday'), [boundary]).length, 1);
});

test('원장 계산', () => {
  const events = [
    ev('penalty', 30, mondayAug25),
    ev('benefit', 15, mondayAug25, 'b'),
    ev('penalty', 60, mondayAug25, 'c'),
  ];
  assert.equal(C.netMinutes(events), -75);
  assert.equal(C.remainingMinutes(events, 420, d(2025, 8, 27), 'monday'), 345);
  // 차감이 기본 시간을 넘으면 음수.
  assert.equal(C.remainingMinutes([ev('penalty', 500, mondayAug25)], 420, d(2025, 8, 27), 'monday'), -80);
  // 지난 주 기록은 이번 주 잔액과 무관.
  assert.equal(C.remainingMinutes([ev('penalty', 100, d(2025, 8, 18))], 420, d(2025, 8, 27), 'monday'), 420);
  // 새 주에는 기본 시간으로 리셋.
  assert.equal(C.remainingMinutes(events, 420, d(2025, 9, 2), 'monday'), 420);
  assert.equal(C.netMinutes([]), 0);
});

test('주 → 일 묶음과 정렬', () => {
  const events = [
    ev('penalty', 30, d(2025, 8, 25, 9, 0), '월요일 아침'),
    ev('benefit', 15, d(2025, 8, 25, 20, 0), '월요일 저녁'),
    ev('penalty', 20, d(2025, 8, 27, 18, 0), '수요일'),
    ev('benefit', 60, d(2025, 9, 2, 10, 0), '다음 주'),
  ];
  const sections = C.groupByWeekThenDay(events, 'monday');
  assert.equal(sections.length, 2);
  assert.equal(+sections[0].interval.start, +d(2025, 9, 1)); // 최신 주가 먼저
  assert.equal(sections[0].netMinutes, 60);
  assert.equal(sections[1].netMinutes, -35);

  const older = sections[1];
  assert.equal(older.days.length, 2);
  assert.equal(+older.days[0].day, +d(2025, 8, 27)); // 일자 최신순
  assert.equal(older.days[1].events[0].name, '월요일 저녁'); // 하루 안에서도 최신순
  assert.equal(older.days[1].netMinutes, -15);
  assert.equal(C.groupByWeekThenDay([], 'monday').length, 0);
});

test('주 시작 요일을 바꾸면 묶음이 재편성되고 총합은 같다', () => {
  const events = [
    ev('penalty', 30, d(2025, 8, 24, 12, 0), '일'),
    ev('penalty', 30, d(2025, 8, 25, 12, 0), '월'),
  ];
  const byMonday = C.groupByWeekThenDay(events, 'monday');
  const bySunday = C.groupByWeekThenDay(events, 'sunday');
  assert.equal(byMonday.length, 2);
  assert.equal(bySunday.length, 1);
  const total = (s) => s.reduce((n, w) => n + w.netMinutes, 0);
  assert.equal(total(byMonday), total(bySunday));
});

test('날짜 문자열', () => {
  assert.equal(C.dayTitle(d(2025, 8, 27)), '8월 27일 (수)');
  assert.equal(C.dayTitle(mondayAug25), '8월 25일 (월)');
  assert.equal(C.dayTitle(sundayAug31), '8월 31일 (일)');
  assert.equal(C.timeLabel(d(2025, 8, 27, 14, 32)), '14:32');
  assert.equal(C.timeLabel(d(2025, 8, 27, 9, 5)), '09:05');

  const week = C.weekInterval(mondayAug25, 'monday');
  assert.equal(C.weekRange(week), '8.25 – 8.31');

  const now = d(2025, 9, 3, 12, 0);
  assert.equal(C.weekTitle(C.weekInterval(now, 'monday'), now, 'monday'), '이번 주');
  assert.equal(C.weekTitle(week, now, 'monday'), '지난 주');
  assert.equal(C.weekTitle(C.weekInterval(d(2025, 8, 20), 'monday'), now, 'monday'), '8.18 – 8.24');
});

test('서머타임이 낀 주도 7일 모두 포함한다', () => {
  // 이 검증은 실행 시간대가 DST를 쓸 때만 의미가 있다. 한국이면 자동으로 통과한다.
  const week = C.weekInterval(new Date(2026, 2, 10, 12, 0), 'sunday');
  for (let i = 0; i < 7; i += 1) {
    const day = new Date(week.start);
    day.setDate(day.getDate() + i);
    assert.ok(C.intervalContains(week, day), `${i}일차가 주에 포함되지 않음`);
  }
  const eighth = new Date(week.start);
  eighth.setDate(eighth.getDate() + 7);
  assert.ok(!C.intervalContains(week, eighth));
});

test('테마 결정', () => {
  const at = (h) => new Date(2025, 7, 25, h, 0);

  // 고정 선택은 시각·기기 설정과 무관하다
  for (const h of [3, 12, 22]) {
    assert.equal(C.effectiveTheme('light', at(h), true), 'light');
    assert.equal(C.effectiveTheme('dark', at(h), false), 'dark');
  }

  // 시스템은 기기 설정을 따른다
  assert.equal(C.effectiveTheme('system', at(12), true), 'dark');
  assert.equal(C.effectiveTheme('system', at(12), false), 'light');
  assert.equal(C.effectiveTheme('system', at(23), false), 'light');

  // 자동은 시각으로만 정한다 (19시~7시 어둡게), 기기 설정 무시
  assert.equal(C.effectiveTheme('auto', at(19), false), 'dark', '19시 정각부터 어둡게');
  assert.equal(C.effectiveTheme('auto', at(23), false), 'dark');
  assert.equal(C.effectiveTheme('auto', at(0), false), 'dark');
  assert.equal(C.effectiveTheme('auto', at(6), false), 'dark');
  assert.equal(C.effectiveTheme('auto', at(7), true), 'light', '7시 정각부터 밝게');
  assert.equal(C.effectiveTheme('auto', at(12), true), 'light');
  assert.equal(C.effectiveTheme('auto', at(18), false), 'light', '18시는 아직 밝게');

  // 모르는 값은 시스템처럼 다룬다
  assert.equal(C.effectiveTheme(undefined, at(12), true), 'dark');
});
