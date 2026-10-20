import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';

// Signature/audience/issuer/expiry are checked by the official SDK using public
// certificates. No service account, private key or administrative RPC is needed.
export function firebaseVerifier({projectId, apiKey, localTest = false}) {
  const emulator = process.env.FIREBASE_AUTH_EMULATOR_HOST;
  if (emulator && !(localTest && projectId.startsWith('demo-') && /^127\.0\.0\.1:\d+$/.test(emulator))) {
    throw new Error('Authentication emulator is forbidden on a production server');
  }
  const app = initializeApp({projectId}, `mp-${crypto.randomUUID()}`);
  const auth = getAuth(app);
  return {
    async verify(token) {
      const claims = await auth.verifyIdToken(token);
      const base = emulator ? `http://${emulator}/identitytoolkit.googleapis.com` : 'https://identitytoolkit.googleapis.com';
      // Also check current account state and revocation on every join/refresh.
      const response = await fetch(`${base}/v1/accounts:lookup?key=${encodeURIComponent(apiKey)}`, {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({idToken: token}), signal: AbortSignal.timeout(8000)
      });
      if (!response.ok) throw new Error('Account lookup refused');
      const user = (await response.json()).users?.[0];
      if (!user || user.localId !== claims.sub || user.emailVerified !== true || user.disabled ||
          Number(user.validSince || 0) > claims.auth_time || claims.email_verified !== true) {
        throw new Error('Account unavailable');
      }
      return {uid: claims.sub, expires: claims.exp};
    },
    close: () => deleteApp(app)
  };
}

export async function readNickname({projectId, token, uid, localTest}) {
  if (localTest) return null;
  const url = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/databases/(default)/documents/chatProfiles/${encodeURIComponent(uid)}`;
  const response = await fetch(url, {headers: {Authorization: `Bearer ${token}`}, signal: AbortSignal.timeout(8000)});
  if (response.status === 404) return null;
  if (!response.ok) throw new Error('Profile unavailable');
  return (await response.json()).fields?.nickname?.stringValue || null;
}
