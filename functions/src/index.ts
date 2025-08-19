// functions/src/index.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { createRemoteJWKSet, jwtVerify, JWTVerifyOptions } from 'jose';
import { setGlobalOptions } from 'firebase-functions/v2/options';
import * as dotenv from 'dotenv';

// Initialize dotenv to load environment variables
dotenv.config();

setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

admin.initializeApp();
const auth = admin.auth();

// --- Corbado OIDC configuration ---
const OIDC_ISSUER = 'https://corbado.stopfires.org'; // issuer (iss)
const OIDC_AUDIENCE = process.env.CORBADO_PROJECT_ID || 'CORBADO_CLIENT_ID'; // aud
const OIDC_JWKS_URI = 'https://corbado.stopfires.org/.well-known/jwks';

// Reuse a remote JWKS (caches & follows key rotation)
const remoteJwks = createRemoteJWKSet(new URL(OIDC_JWKS_URI));

// ---- Verify Corbado ID token ----
async function verifyCorbadoIdToken(idToken: string) {
  // After (temporary):
  const verifyOpts: JWTVerifyOptions = { issuer: OIDC_ISSUER };

  // Validates signature (via JWKS), exp/nbf/iat, iss, aud.
  const { payload, protectedHeader } = await jwtVerify(
    idToken,
    remoteJwks,
    verifyOpts
  );

  if (!payload.sub) throw new Error("OIDC token missing 'sub'");

  // Optional hardening examples:
  // if (payload.email_verified !== true) throw new Error("Email not verified");
  // if (payload.nonce !== expectedNonce) throw new Error("Invalid nonce");

  return { payload, header: protectedHeader };
}

async function ensureFirebaseUser(uid: string, email?: string) {
  try {
    await auth.getUser(uid);
  } catch (err: any) {
    if (err.code === 'auth/user-not-found') {
      await auth.createUser({ uid, email }).catch(() => undefined);
    } else {
      throw err;
    }
  }
}

/**
 * HTTPS Callable: verify a Corbado ID token and mint a Firebase Custom Token.
 * Expects: { idToken: string }
 * Returns: { customToken, uid, email }
 */
export const verifyAndMint = functions.https.onCall(async (data, _context) => {
  const idToken = data.data?.idToken as string | undefined;
  if (!idToken) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'idToken is required'
    );
  }
  if (!OIDC_AUDIENCE || OIDC_AUDIENCE === 'CORBADO_CLIENT_ID') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Set CORBADO_CLIENT_ID'
    );
  }

  try {
    const { payload } = await verifyCorbadoIdToken(idToken);

    const sub = String(payload.sub);
    const email = typeof payload.email === 'string' ? payload.email : undefined;

    // Namespace your Firebase UID to avoid collisions
    const uid = `corbado:${sub}`;

    await ensureFirebaseUser(uid, email);
    const RESERVED = new Set([
      'iss',
      'aud',
      'sub',
      'iat',
      'exp',
      'nbf',
      'jti',
      'uid',
      'claims',
      'tenant_id',
      'firebase',
    ]);

    function sanitizeClaims(input: Record<string, unknown>) {
      const out: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(input)) {
        if (!RESERVED.has(k)) out[k] = v;
      }
      return out;
    }

    const rawClaims = {
      provider: 'corbado',
      email,
      email_verified: payload.email_verified === true,
      // add your own authorization flags here, e.g. roles, orgId, etc.
    };

    const claims = sanitizeClaims(rawClaims); // strips any accidental reserved keys

    const customToken = await auth.createCustomToken(uid, claims);
    return { customToken, uid, email };
  } catch (e: any) {
    console.error('verifyAndMint failed:', e);
    throw new functions.https.HttpsError(
      'unauthenticated',
      e.message ?? 'Token verification failed'
    );
  }
});

/**
 * Optional: verify-only endpoint (no minting)
 */
export const verifyCorbado = functions.https.onCall(async (data, _context) => {
  const idToken = data.data?.idToken as string | undefined;
  if (!idToken) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'idToken is required'
    );
  }
  try {
    const { payload, header } = await verifyCorbadoIdToken(idToken);
    return { valid: true, header, payload };
  } catch (e: any) {
    console.error('verifyCorbado failed:', e);
    throw new functions.https.HttpsError(
      'unauthenticated',
      e.message ?? 'Token verification failed'
    );
  }
});
