// 설정과 기록을 localStorage 한 칸에 JSON으로 담는다.
// 홈 화면에 추가한 웹앱은 자체 사용 카운터를 가져 사파리 탭보다 오래 보존되지만,
// 저장공간 압박 시 삭제될 여지가 있어 내보내기/불러오기를 함께 둔다.

const KEY = 'gametimer.state.v1';

export const MAX_WEEKLY_BASE_MINUTES = 6000;

const DEFAULT_SETTINGS = {
  weeklyBaseMinutes: 420, // 하루 1시간
  weekStart: 'monday',
  theme: 'system', // system | light | dark | auto

  penalties: [
    { name: '숙제 미완료', minutes: 30 },
    { name: '약속 시간 어김', minutes: 20 },
    { name: '게임 시간 초과', minutes: 30 },
    { name: '정리 안 함', minutes: 15 },
    { name: '거짓말', minutes: 60 },
  ],
  benefits: [
    { name: '책 읽기', minutes: 15 },
    { name: '심부름', minutes: 10 },
    { name: '운동하기', minutes: 20 },
    { name: '숙제 미리 끝냄', minutes: 20 },
    { name: '시험 잘 봄', minutes: 60 },
  ],
};

export function newId() {
  return crypto.randomUUID();
}

function withIds(presets) {
  return presets.map((p) => ({ id: newId(), ...p }));
}

export function defaultState() {
  return {
    version: 1,
    settings: {
      ...DEFAULT_SETTINGS,
      penalties: withIds(DEFAULT_SETTINGS.penalties),
      benefits: withIds(DEFAULT_SETTINGS.benefits),
    },
    events: [],
    auth: { credentialId: null, pinHash: null, pinSalt: null },
  };
}

const clamp = (n, lo, hi) => Math.min(Math.max(n, lo), hi);

function sanitizePreset(preset) {
  const name = String(preset?.name ?? '').trim();
  if (!name) return null;
  const minutes = Number(preset?.minutes);
  return {
    id: preset?.id ?? newId(),
    name,
    minutes: clamp(Number.isFinite(minutes) ? Math.round(minutes) : 1, 1, 1440),
  };
}

/** 깨진 값이 섞여 있어도 살릴 수 있는 것만 살린다. 원소 하나 때문에 전체를 잃지 않게. */
function sanitize(raw) {
  const base = defaultState();
  if (!raw || typeof raw !== 'object') return base;

  const s = raw.settings ?? {};
  const minutes = Number(s.weeklyBaseMinutes);
  const settings = {
    weeklyBaseMinutes: clamp(
      Number.isFinite(minutes) ? Math.round(minutes) : base.settings.weeklyBaseMinutes,
      0,
      MAX_WEEKLY_BASE_MINUTES,
    ),
    weekStart: s.weekStart === 'sunday' ? 'sunday' : 'monday',
    theme: ['system', 'light', 'dark', 'auto'].includes(s.theme) ? s.theme : 'system',
    penalties: Array.isArray(s.penalties)
      ? s.penalties.map(sanitizePreset).filter(Boolean)
      : base.settings.penalties,
    benefits: Array.isArray(s.benefits)
      ? s.benefits.map(sanitizePreset).filter(Boolean)
      : base.settings.benefits,
  };

  const events = Array.isArray(raw.events)
    ? raw.events
        .map((e) => {
          const when = new Date(e?.date);
          const mins = Number(e?.minutes);
          if (Number.isNaN(when.getTime()) || !Number.isFinite(mins)) return null;
          if (e?.kind !== 'penalty' && e?.kind !== 'benefit') return null;
          return {
            id: e.id ?? newId(),
            kind: e.kind,
            name: String(e.name ?? ''),
            minutes: Math.max(0, Math.round(mins)),
            date: when.toISOString(),
          };
        })
        .filter(Boolean)
    : [];

  return {
    version: 1,
    settings,
    events,
    auth: {
      credentialId: raw.auth?.credentialId ?? null,
      pinHash: raw.auth?.pinHash ?? null,
      pinSalt: raw.auth?.pinSalt ?? null,
    },
  };
}

export function load() {
  let raw = null;
  try {
    raw = localStorage.getItem(KEY);
  } catch {
    // 사파리 프라이빗 모드 등에서 접근이 막힐 수 있다.
    return defaultState();
  }
  if (raw === null) return defaultState(); // 첫 실행
  try {
    return sanitize(JSON.parse(raw));
  } catch {
    // 내용이 깨졌으면 원본을 옆에 남겨 두고 기본값으로 시작한다.
    try {
      localStorage.setItem(`${KEY}.corrupt.${Date.now()}`, raw);
    } catch { /* 저장공간이 없으면 어쩔 수 없다 */ }
    return defaultState();
  }
}

/** 저장 성공 여부를 돌려준다. 실패를 조용히 삼키면 다음 실행에서 기록이 통째로 사라진다. */
export function save(state) {
  try {
    localStorage.setItem(KEY, JSON.stringify(state));
    return true;
  } catch {
    return false;
  }
}

// ---------- 백업 ----------

export function exportJSON(state) {
  return JSON.stringify({ ...state, auth: undefined }, null, 2);
}

/** 백업 파일을 되돌린다. 인증 정보는 기기마다 다르므로 현재 값을 유지한다. */
export function importJSON(text, currentAuth) {
  const parsed = sanitize(JSON.parse(text));
  return { ...parsed, auth: currentAuth };
}
