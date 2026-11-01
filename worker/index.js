// ChatVibe push + call-token server (Cloudflare Worker, free plan).
//
// Replaces the two Firebase Cloud Functions the app used to need:
//   POST /push        -> sends a push notification (new message, or incoming call)
//   POST /call-token  -> mints a LiveKit access token for a chat's call
//
// Every request must carry the signed-in user's Firebase ID token:
//   Authorization: Bearer <idToken>
// The Worker verifies it, then reads Firestore *as that user* (so your Firestore
// security rules still apply) to confirm they belong to the chat.
//
// Settings (Worker > Settings > Variables and Secrets):
//   FIREBASE_PROJECT_ID      (text)    e.g. my-chat-app-262ef
//   LIVEKIT_URL              (text)    e.g. wss://your-app.livekit.cloud
//   GOOGLE_SERVICE_ACCOUNT   (secret)  the full JSON of a Firebase service-account key
//   LIVEKIT_API_KEY          (secret)
//   LIVEKIT_API_SECRET       (secret)

const MAX_RECIPIENTS = 20; // free plan allows 50 outgoing requests per invocation

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== 'POST') return json({ ok: true, service: 'chatvibe-push' });

    try {
      const idToken = (request.headers.get('Authorization') || '').replace(/^Bearer\s+/i, '');
      if (!idToken) throw httpError(401, 'Missing token');
      const user = await verifyFirebaseIdToken(idToken, env);
      const body = await request.json().catch(() => ({}));

      if (url.pathname === '/push') return json(await handlePush(user, body, env));
      if (url.pathname === '/call-token') return json(await handleCallToken(user, body, env));
      return json({ error: 'Not found' }, 404);
    } catch (e) {
      return json({ error: e.message || String(e) }, e.status || 500);
    }
  },
};

// ---------------------------------------------------------------- handlers

async function handlePush(user, body, env) {
  const { kind, chatId, messageId, video } = body;
  if (!chatId || (kind !== 'message' && kind !== 'call')) throw httpError(400, 'Bad request');

  const chat = await fsGet(`chats/${chatId}`, user.token, env);
  if (!chat) throw httpError(404, 'Chat not found');
  const participants = chat.participants || [];
  if (!participants.includes(user.uid)) throw httpError(403, 'Not in this chat');

  const sender = await fsGet(`users/${user.uid}`, user.token, env);
  const senderName = (sender && sender.username) || 'Someone';
  const isGroup = chat.isGroup === true;
  const groupName = chat.groupName || 'Group';

  let notification, data, channelId, ttl;
  if (kind === 'message') {
    if (!messageId) throw httpError(400, 'Missing messageId');
    const msg = await fsGet(`chats/${chatId}/messages/${messageId}`, user.token, env);
    if (!msg || msg.senderId !== user.uid) throw httpError(403, 'Not your message');
    const text = preview(msg);
    notification = {
      title: isGroup ? groupName : senderName,
      body: isGroup ? `${senderName}: ${text}` : text,
    };
    data = { type: 'message', chatId, isGroup: String(isGroup), title: notification.title, senderUid: user.uid };
    channelId = 'messages';
    ttl = '86400s';
  } else {
    notification = {
      title: `${senderName} is calling`,
      body: isGroup ? `${video ? 'Video' : 'Voice'} call in ${groupName}` : (video ? 'Video call' : 'Voice call'),
    };
    data = {
      type: 'call', chatId, isGroup: String(isGroup), video: String(!!video),
      callerName: senderName, groupName, senderUid: user.uid,
    };
    channelId = 'calls';
    ttl = '30s';
  }

  // Everyone except the sender; muted chats don't get message pushes.
  const recipients = participants
    .filter((uid) => uid !== user.uid)
    .filter((uid) => !(kind === 'message' && chat.muted && chat.muted[uid] === true))
    .slice(0, MAX_RECIPIENTS);

  const profiles = await Promise.all(recipients.map((uid) => fsGet(`users/${uid}`, user.token, env).catch(() => null)));
  const tokens = profiles.map((p) => p && p.fcmToken).filter(Boolean);
  if (tokens.length === 0) return { sent: 0 };

  const accessToken = await getFcmAccessToken(env);
  const results = await Promise.all(tokens.map((token) => sendFcm(env, accessToken, { token, notification, data, channelId, ttl, chatId })));
  return { sent: results.filter(Boolean).length };
}

async function handleCallToken(user, body, env) {
  const { roomName } = body;
  if (!roomName) throw httpError(400, 'Missing roomName');
  const collection = body.collection === 'rooms' ? 'rooms' : 'chats';

  if (collection === 'chats') {
    const chat = await fsGet(`chats/${roomName}`, user.token, env);
    if (!chat || !(chat.participants || []).includes(user.uid)) throw httpError(403, 'Not in this chat');
  } else {
    const member = await fsGet(`rooms/${roomName}/members/${user.uid}`, user.token, env);
    if (!member) throw httpError(403, 'Not in this room');
  }

  const profile = await fsGet(`users/${user.uid}`, user.token, env).catch(() => null);
  const token = await makeLiveKitToken(env, roomName, user.uid, (profile && profile.username) || 'User');
  return { token, url: env.LIVEKIT_URL };
}

function preview(m) {
  switch (m.type) {
    case 'image': return '📷 Photo';
    case 'video': return '🎥 Video';
    case 'voice': return '🎤 Voice message';
    case 'file': return '📎 ' + (m.fileName || 'File');
    case 'poll': return '📊 ' + (m.pollQuestion || 'Poll');
    default: return String(m.text || '').slice(0, 140);
  }
}

// ---------------------------------------------------------------- FCM

let fcmTokenCache = { token: null, expires: 0 };

async function getFcmAccessToken(env) {
  if (fcmTokenCache.token && Date.now() < fcmTokenCache.expires - 60000) return fcmTokenCache.token;
  const sa = JSON.parse(env.GOOGLE_SERVICE_ACCOUNT);
  const now = Math.floor(Date.now() / 1000);
  const unsigned =
    b64urlText(JSON.stringify({ alg: 'RS256', typ: 'JWT' })) + '.' +
    b64urlText(JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }));
  const key = await crypto.subtle.importKey(
    'pkcs8', pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned));
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: unsigned + '.' + b64urlBytes(new Uint8Array(sig)),
    }),
  });
  const j = await res.json();
  if (!j.access_token) throw httpError(502, 'Could not get a Google access token (check GOOGLE_SERVICE_ACCOUNT)');
  fcmTokenCache = { token: j.access_token, expires: Date.now() + (j.expires_in || 3600) * 1000 };
  return j.access_token;
}

async function sendFcm(env, accessToken, { token, notification, data, channelId, ttl, chatId }) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      message: {
        token,
        notification,
        data,
        android: {
          priority: 'HIGH',
          ttl,
          notification: { channel_id: channelId, tag: channelId + ':' + chatId },
        },
      },
    }),
  });
  return res.ok;
}

// ---------------------------------------------------------------- LiveKit

async function makeLiveKitToken(env, room, identity, name) {
  const now = Math.floor(Date.now() / 1000);
  const unsigned =
    b64urlText(JSON.stringify({ alg: 'HS256', typ: 'JWT' })) + '.' +
    b64urlText(JSON.stringify({
      iss: env.LIVEKIT_API_KEY,
      sub: identity,
      name,
      nbf: now - 10,
      iat: now,
      exp: now + 2 * 3600,
      video: { room, roomJoin: true, canPublish: true, canSubscribe: true, canPublishData: true },
    }));
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(env.LIVEKIT_API_SECRET),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(unsigned));
  return unsigned + '.' + b64urlBytes(new Uint8Array(sig));
}

// ---------------------------------------------------------------- Firebase auth + Firestore

let jwksCache = { keys: null, expires: 0 };

async function getJwks() {
  if (jwksCache.keys && Date.now() < jwksCache.expires) return jwksCache.keys;
  const res = await fetch('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
  const j = await res.json();
  jwksCache = { keys: j.keys, expires: Date.now() + 3600 * 1000 };
  return j.keys;
}

async function verifyFirebaseIdToken(token, env) {
  const parts = token.split('.');
  if (parts.length !== 3) throw httpError(401, 'Bad token');
  let header, payload;
  try {
    header = JSON.parse(b64urlToText(parts[0]));
    payload = JSON.parse(b64urlToText(parts[1]));
  } catch (_) {
    throw httpError(401, 'Bad token');
  }
  if (header.alg !== 'RS256') throw httpError(401, 'Bad token');
  const jwk = (await getJwks()).find((k) => k.kid === header.kid);
  if (!jwk) throw httpError(401, 'Unknown signing key');
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify']);
  const valid = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5', key, b64urlToBytes(parts[2]), new TextEncoder().encode(parts[0] + '.' + parts[1]),
  );
  const now = Math.floor(Date.now() / 1000);
  if (
    !valid ||
    payload.exp < now ||
    payload.aud !== env.FIREBASE_PROJECT_ID ||
    payload.iss !== `https://securetoken.google.com/${env.FIREBASE_PROJECT_ID}` ||
    !payload.sub
  ) {
    throw httpError(401, 'Invalid token');
  }
  return { uid: payload.sub, token };
}

// Reads a Firestore document as the signed-in user. Returns null if it doesn't exist.
async function fsGet(path, idToken, env) {
  const res = await fetch(
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/databases/(default)/documents/${path}`,
    { headers: { Authorization: `Bearer ${idToken}` } },
  );
  if (res.status === 404) return null;
  if (res.status === 403) throw httpError(403, 'Firestore rules denied this read');
  if (!res.ok) throw httpError(502, `Firestore error ${res.status}`);
  const doc = await res.json();
  return decodeFields(doc.fields || {});
}

function decodeFields(fields) {
  const out = {};
  for (const k of Object.keys(fields)) out[k] = decodeValue(fields[k]);
  return out;
}

function decodeValue(v) {
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decodeValue);
  if ('mapValue' in v) return decodeFields(v.mapValue.fields || {});
  return null;
}

// ---------------------------------------------------------------- small helpers

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { 'Content-Type': 'application/json' } });
}

function httpError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

function b64urlBytes(bytes) {
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlText(text) {
  return b64urlBytes(new TextEncoder().encode(text));
}

function b64urlToBytes(s) {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const bin = atob(s);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function b64urlToText(s) {
  return new TextDecoder().decode(b64urlToBytes(s));
}

function pemToDer(pem) {
  const b64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out.buffer;
}
