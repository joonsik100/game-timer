import * as C from './core.js';
import * as Store from './store.js';
import * as Auth from './auth.js';

let state = Store.load();
let saveFailed = false;
/** 인증 창이 떠 있는 동안 다른 버튼이 또 인증을 걸지 못하게 막는다. */
let authenticating = false;

const $ = (id) => document.getElementById(id);
const el = (tag, cls, text) => {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text !== undefined) n.textContent = text;
  return n;
};

// ---------- 저장 ----------

function persist() {
  saveFailed = !Store.save(state);
  $('save-warning').hidden = !saveFailed;
}

// ---------- 화면 전환 ----------

const SCREENS = ['setup', 'main', 'history', 'settings'];
function show(name) {
  for (const s of SCREENS) $(`screen-${s}`).hidden = s !== name;
  if (name === 'main') renderMain();
  if (name === 'history') renderHistory();
  if (name === 'settings') renderSettings();
}

let toastTimer;
function toast(message) {
  const node = $('toast');
  node.textContent = message;
  node.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { node.hidden = true; }, 2200);
}

// ---------- 본인 확인 ----------

/** Face ID → 실패하면 예비 PIN. 통과하면 true. */
async function requireAuth(reason) {
  if (authenticating) return false;
  authenticating = true;
  try {
    const { credentialId, pinHash } = state.auth;
    if (credentialId && (await Auth.verifyFaceId(credentialId))) return true;
    if (pinHash) return await askPin(reason);
    // 등록된 수단이 하나도 없다면 확인할 방법이 없다. 첫 실행 화면으로 되돌린다.
    if (!credentialId && !pinHash) {
      show('setup');
      return false;
    }
    return false;
  } finally {
    authenticating = false;
  }
}

function askPin(reason) {
  return new Promise((resolve) => {
    const dialog = $('pin-dialog');
    const input = $('pin-input');
    const error = $('pin-error');
    $('pin-reason').textContent = reason ?? '';
    input.value = '';
    error.textContent = '';

    const onSubmit = async (event) => {
      event.preventDefault();
      const ok = await Auth.verifyPin(input.value, state.auth.pinHash, state.auth.pinSalt);
      if (!ok) {
        error.textContent = 'PIN이 맞지 않습니다';
        input.value = '';
        return;
      }
      cleanup();
      dialog.close();
      resolve(true);
    };
    const onCancel = () => { cleanup(); dialog.close(); resolve(false); };
    const cleanup = () => {
      $('pin-form').removeEventListener('submit', onSubmit);
      dialog.querySelector('[data-close]').removeEventListener('click', onCancel);
    };

    $('pin-form').addEventListener('submit', onSubmit);
    dialog.querySelector('[data-close]').addEventListener('click', onCancel);
    dialog.showModal();
    input.focus();
  });
}

// ---------- 메인 ----------

function renderMain() {
  const now = new Date();
  const { weeklyBaseMinutes, weekStart } = state.settings;
  const remaining = C.remainingMinutes(state.events, weeklyBaseMinutes, now, weekStart);

  $('remaining').textContent = C.hhmm(remaining);
  $('remaining-sub').textContent =
    remaining < 0 ? '시간을 초과했어요' : `기본 ${C.hhmm(weeklyBaseMinutes)}`;
  $('save-warning').hidden = !saveFailed;

  for (const kind of ['penalty', 'benefit']) {
    const list = $(`${kind}-list`);
    list.replaceChildren();
    const presets = state.settings[kind === 'penalty' ? 'penalties' : 'benefits'];
    if (presets.length === 0) {
      list.append(el('p', 'muted small', '설정에서 항목을 추가하세요'));
      continue;
    }
    for (const preset of presets) {
      const button = el('button', `adjust ${kind}`);
      button.append(el('span', 'name', preset.name));
      button.append(el('span', 'mins', C.signedLabel(C.signOf(kind) * preset.minutes)));
      button.addEventListener('click', () => applyPreset(preset, kind));
      list.append(button);
    }
  }
}

async function applyPreset(preset, kind) {
  if (authenticating) return;
  if (!(await requireAuth('게임 시간을 조정하려면 본인 확인이 필요합니다'))) return;
  state.events.push({
    id: Store.newId(),
    kind,
    // 누른 시점의 이름과 분을 박제해 나중에 항목을 고쳐도 과거가 변하지 않게 한다.
    name: preset.name,
    minutes: preset.minutes,
    date: new Date().toISOString(),
  });
  persist();
  renderMain();
  toast(`${preset.name} ${C.signedLabel(C.signOf(kind) * preset.minutes)}`);
}

// ---------- 기록 ----------

function renderHistory() {
  const body = $('history-body');
  body.replaceChildren();
  const now = new Date();
  const sections = C.groupByWeekThenDay(state.events, state.settings.weekStart);

  if (sections.length === 0) {
    const empty = el('div', 'empty');
    empty.append(el('p', null, '아직 기록이 없어요'));
    empty.append(el('p', 'small', '메인 화면에서 차감/추가 버튼을 누르면 여기에 쌓입니다.'));
    body.append(empty);
    return;
  }

  for (const week of sections) {
    const head = el('div', 'week-head');
    head.append(el('span', null, C.weekTitle(week.interval, now, state.settings.weekStart)));
    head.append(el('span', 'spacer'));
    head.append(el('span', 'mono', C.netLabel(week.netMinutes)));
    body.append(head);

    for (const day of week.days) {
      const dayHead = el('div', 'day-head');
      dayHead.append(el('span', null, C.dayTitle(day.day)));
      dayHead.append(el('span', 'spacer'));
      dayHead.append(el('span', 'mono', C.netLabel(day.netMinutes)));
      body.append(dayHead);

      const entries = el('div', 'entries');
      for (const event of day.events) {
        const row = el('div', 'entry');
        row.append(el('span', `badge ${event.kind}`, event.kind === 'penalty' ? '차감' : '추가'));
        const info = el('div', 'info');
        info.append(el('span', 'name', event.name));
        info.append(el('span', 'at', C.timeLabel(event.date)));
        row.append(info);
        row.append(el('span', 'delta mono', C.signedLabel(C.signedMinutesOf(event))));
        const del = el('button', 'del', '×');
        del.setAttribute('aria-label', '삭제');
        del.addEventListener('click', () => deleteEvent(event.id));
        row.append(del);
        entries.append(row);
      }
      body.append(entries);
    }
  }
}

async function deleteEvent(id) {
  // 기록을 지우는 것도 결국 시간을 되돌리는 일이라 똑같이 본인 확인을 받는다.
  if (!(await requireAuth('기록을 지우려면 본인 확인이 필요합니다'))) return;
  state.events = state.events.filter((e) => e.id !== id);
  persist();
  renderHistory();
}

// ---------- 설정 ----------

function renderSettings() {
  renderAuthSection();
  $('base-minutes').value = state.settings.weeklyBaseMinutes;
  $('base-hhmm').textContent = C.hhmm(state.settings.weeklyBaseMinutes);
  for (const button of document.querySelectorAll('[data-week-start]')) {
    button.setAttribute('aria-checked', String(button.dataset.weekStart === state.settings.weekStart));
  }

  for (const kind of ['penalty', 'benefit']) {
    const container = $(`${kind}-settings`);
    container.replaceChildren();
    const presets = state.settings[kind === 'penalty' ? 'penalties' : 'benefits'];
    if (presets.length === 0) {
      container.append(el('p', 'muted small', '항목이 없습니다'));
      continue;
    }
    for (const preset of presets) {
      const row = el('button', 'preset-row');
      row.append(el('span', null, preset.name));
      row.append(el('span', 'spacer'));
      row.append(el('span', 'mins', C.signedLabel(C.signOf(kind) * preset.minutes)));
      row.append(el('span', 'chev', '›'));
      row.addEventListener('click', () => openPresetDialog(kind, preset));
      container.append(row);
    }
  }
}

async function renderAuthSection() {
  const status = $('faceid-status');
  const button = $('register-faceid');
  const note = $('auth-note');
  const registered = !!state.auth.credentialId;

  status.textContent = registered ? '등록됨' : '등록 안 됨';
  button.textContent = registered ? 'Face ID 다시 등록' : 'Face ID 등록하기';
  note.textContent = registered
    ? '시간을 바꾸거나 설정을 열 때 Face ID로 확인합니다. 인식되지 않으면 예비 PIN을 묻습니다.'
    : 'Face ID가 등록되어 있지 않아 예비 PIN으로만 확인합니다. 위 버튼으로 등록하세요.';

  const available = await Auth.faceIdAvailable();
  if (!available) {
    button.disabled = true;
    status.textContent = '이 기기에서 사용 불가';
    note.textContent = 'Face ID를 쓰려면 HTTPS 주소에서 열어야 합니다. 예비 PIN으로 계속 쓸 수 있습니다.';
  }
}

function openPresetDialog(kind, preset) {
  const dialog = $('preset-dialog');
  const isNew = !preset;
  $('preset-title').textContent =
    `${kind === 'penalty' ? '차감' : '추가'} 항목 ${isNew ? '추가' : '편집'}`;
  $('preset-name').value = preset?.name ?? '';
  $('preset-minutes').value = preset?.minutes ?? (kind === 'penalty' ? 30 : 15);
  $('preset-delete').hidden = isNew;

  const quick = $('preset-quick');
  quick.replaceChildren();
  for (const minutes of [10, 15, 30, 60]) {
    const button = el('button', null, `${minutes}분`);
    button.type = 'button';
    button.addEventListener('click', () => { $('preset-minutes').value = minutes; });
    quick.append(button);
  }

  const key = kind === 'penalty' ? 'penalties' : 'benefits';
  const onSubmit = (event) => {
    event.preventDefault();
    const name = $('preset-name').value.trim();
    if (!name) return;
    const minutes = Math.min(Math.max(Number($('preset-minutes').value) || 1, 1), 1440);
    if (isNew) {
      state.settings[key].push({ id: Store.newId(), name, minutes });
    } else {
      const target = state.settings[key].find((p) => p.id === preset.id);
      if (target) { target.name = name; target.minutes = minutes; }
    }
    finish();
  };
  const onDelete = () => {
    state.settings[key] = state.settings[key].filter((p) => p.id !== preset.id);
    finish();
  };
  const onCancel = () => { cleanup(); dialog.close(); };
  const finish = () => { persist(); cleanup(); dialog.close(); renderSettings(); };
  const cleanup = () => {
    $('preset-form').removeEventListener('submit', onSubmit);
    $('preset-delete').removeEventListener('click', onDelete);
    dialog.querySelector('[data-close]').removeEventListener('click', onCancel);
  };

  $('preset-form').addEventListener('submit', onSubmit);
  $('preset-delete').addEventListener('click', onDelete);
  dialog.querySelector('[data-close]').addEventListener('click', onCancel);
  dialog.showModal();
}

// ---------- 배선 ----------

function wire() {
  $('go-history').addEventListener('click', () => show('history'));
  $('go-settings').addEventListener('click', async () => {
    // 설정에서 기본 시간과 항목을 바꾸면 잔여 시간이 달라지므로 여기도 잠근다.
    if (!(await requireAuth('설정을 열려면 본인 확인이 필요합니다'))) return;
    show('settings');
  });
  for (const button of document.querySelectorAll('[data-back]')) {
    button.addEventListener('click', () => show('main'));
  }

  $('base-minutes').addEventListener('change', (event) => {
    const value = Math.min(Math.max(Number(event.target.value) || 0, 0), Store.MAX_WEEKLY_BASE_MINUTES);
    state.settings.weeklyBaseMinutes = value;
    event.target.value = value;
    $('base-hhmm').textContent = C.hhmm(value);
    persist();
  });

  for (const button of document.querySelectorAll('[data-week-start]')) {
    button.addEventListener('click', () => {
      state.settings.weekStart = button.dataset.weekStart;
      persist();
      renderSettings();
    });
  }

  for (const button of document.querySelectorAll('[data-add]')) {
    button.addEventListener('click', () => openPresetDialog(button.dataset.add, null));
  }

  $('register-faceid').addEventListener('click', async () => {
    try {
      state.auth.credentialId = await Auth.registerFaceId();
      persist();
      renderAuthSection();
      toast('Face ID가 등록되었습니다');
    } catch {
      toast('Face ID를 등록하지 못했습니다');
    }
  });

  $('change-pin').addEventListener('click', async () => {
    // 지금 PIN을 아는 사람만 바꿀 수 있게 한다.
    if (state.auth.pinHash && !(await requireAuth('예비 PIN을 바꾸려면 본인 확인이 필요합니다'))) return;
    const next = prompt('새 예비 PIN (4자리 이상 숫자)');
    if (next === null) return;
    if (!/^\d{4,}$/.test(next)) {
      toast('4자리 이상 숫자여야 합니다');
      return;
    }
    const { hash, salt } = await Auth.hashPin(next);
    state.auth.pinHash = hash;
    state.auth.pinSalt = salt;
    persist();
    toast('예비 PIN을 바꿨습니다');
  });

  $('export-data').addEventListener('click', () => {
    const blob = new Blob([Store.exportJSON(state)], { type: 'application/json' });
    const link = el('a');
    link.href = URL.createObjectURL(blob);
    const stamp = new Date().toISOString().slice(0, 10);
    link.download = `게임타이머-백업-${stamp}.json`;
    link.click();
    URL.revokeObjectURL(link.href);
  });
  $('import-data').addEventListener('click', () => $('import-file').click());
  $('import-file').addEventListener('change', async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    try {
      state = Store.importJSON(await file.text(), state.auth);
      persist();
      renderSettings();
      toast('불러왔습니다');
    } catch {
      toast('파일을 읽지 못했습니다');
    }
    event.target.value = '';
  });

  // 첫 실행 화면
  $('setup-faceid').addEventListener('click', async () => {
    try {
      state.auth.credentialId = await Auth.registerFaceId();
      persist();
      $('setup-faceid-note').textContent = 'Face ID가 등록되었습니다.';
      $('setup-error').textContent = '';
    } catch {
      $('setup-error').textContent = 'Face ID를 등록하지 못했습니다. 예비 PIN만으로도 시작할 수 있습니다.';
    }
  });
  $('setup-done').addEventListener('click', async () => {
    const pin = $('setup-pin').value;
    if (pin && pin.length < 4) {
      $('setup-error').textContent = 'PIN은 4자리 이상이어야 합니다.';
      return;
    }
    if (!pin && !state.auth.credentialId) {
      $('setup-error').textContent = 'Face ID를 등록하거나 예비 PIN을 정해 주세요.';
      return;
    }
    if (pin) {
      const { hash, salt } = await Auth.hashPin(pin);
      state.auth.pinHash = hash;
      state.auth.pinSalt = salt;
    }
    persist();
    show('main');
  });

  // 주가 바뀌는 순간을 놓치지 않도록 1분마다 다시 그린다.
  setInterval(() => { if (!$('screen-main').hidden) renderMain(); }, 60_000);
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden && !$('screen-main').hidden) renderMain();
  });
}

async function start() {
  wire();
  const needsSetup = !state.auth.credentialId && !state.auth.pinHash;
  if (needsSetup) {
    show('setup');
    const available = await Auth.faceIdAvailable();
    if (!available) {
      $('setup-faceid').disabled = true;
      $('setup-faceid-note').textContent =
        '이 브라우저에서는 Face ID를 쓸 수 없습니다. 예비 PIN으로 진행하세요. (HTTPS 주소에서 열어야 합니다)';
    }
  } else {
    show('main');
  }
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').catch(() => { /* 오프라인 캐시는 없어도 동작한다 */ });
  }
}

start();
