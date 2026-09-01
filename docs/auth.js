// Face ID 잠금. iOS 사파리의 WebAuthn(패스키) 플랫폼 인증기를 부르면 Face ID 창이 뜬다.
//
// 서버가 없으므로 서명을 검증하지는 않는다. 즉 암호학적 강제가 아니라
// "기기 소유자 확인" 수준이다. 네이티브 판의 LocalAuthentication도 같은 성격이고,
// 안내 접근으로 고정된 아이패드에서는 아이가 개발자 도구를 열 수단이 없다.

const RP_NAME = '게임 타이머';

const toB64 = (buf) =>
  btoa(String.fromCharCode(...new Uint8Array(buf))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

const fromB64 = (s) => {
  const padded = s.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(padded + '='.repeat((4 - (padded.length % 4)) % 4));
  return Uint8Array.from(bin, (c) => c.charCodeAt(0));
};

const randomBytes = (n) => crypto.getRandomValues(new Uint8Array(n));

export async function faceIdAvailable() {
  if (!window.PublicKeyCredential || !window.isSecureContext) return false;
  try {
    return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
  } catch {
    return false;
  }
}

/** 최초 1회: 이 기기에 패스키를 만든다. 성공하면 자격증명 ID를 돌려준다. */
export async function registerFaceId() {
  const credential = await navigator.credentials.create({
    publicKey: {
      challenge: randomBytes(32),
      rp: { name: RP_NAME, id: location.hostname },
      user: { id: randomBytes(16), name: 'parent', displayName: '보호자' },
      pubKeyCredParams: [
        { type: 'public-key', alg: -7 },   // ES256
        { type: 'public-key', alg: -257 }, // RS256
      ],
      authenticatorSelection: {
        authenticatorAttachment: 'platform',
        userVerification: 'required',
        residentKey: 'preferred',
      },
      attestation: 'none',
      timeout: 60000,
    },
  });
  if (!credential) throw new Error('패스키를 만들지 못했습니다');
  return toB64(credential.rawId);
}

/** Face ID 확인. 통과하면 true, 사용자가 취소하면 false. */
export async function verifyFaceId(credentialId) {
  try {
    const assertion = await navigator.credentials.get({
      publicKey: {
        challenge: randomBytes(32),
        rpId: location.hostname,
        allowCredentials: credentialId
          ? [{ type: 'public-key', id: fromB64(credentialId) }]
          : [],
        userVerification: 'required',
        timeout: 60000,
      },
    });
    return !!assertion;
  } catch {
    return false;
  }
}

// ---------- PIN 예비 수단 ----------
//
// Face ID를 못 쓰는 상황(패스키 삭제, 인식 실패 반복)에서 앱이 영영 잠기는 것을 막는다.
// 네이티브 판이 기기 암호로 대체하는 것과 같은 역할이다.

export async function hashPin(pin, saltB64) {
  const salt = saltB64 ? fromB64(saltB64) : randomBytes(16);
  const data = new TextEncoder().encode(`${toB64(salt)}:${pin}`);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return { hash: toB64(digest), salt: toB64(salt) };
}

export async function verifyPin(pin, storedHash, storedSalt) {
  if (!storedHash || !storedSalt) return false;
  const { hash } = await hashPin(pin, storedSalt);
  // 길이가 같은 문자열 비교라 타이밍 차이는 실질적 위험이 아니다(로컬 기기 한정).
  return hash === storedHash;
}
