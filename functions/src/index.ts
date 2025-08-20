// functions/src/index.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { createRemoteJWKSet, jwtVerify, JWTVerifyOptions } from 'jose';
import { setGlobalOptions } from 'firebase-functions/v2/options';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import * as dotenv from 'dotenv';

// Initialize dotenv to load environment variables
dotenv.config();

setGlobalOptions({ region: 'europe-west1', maxInstances: 10 });

admin.initializeApp();
const auth = admin.auth();

// Logger configuration
const logger = {
  info: (message: string, ...args: any[]) => {
    console.log(`[INFO] ${message}`, ...args);
  },
  warn: (message: string, ...args: any[]) => {
    console.warn(`[WARN] ${message}`, ...args);
  },
  error: (message: string, ...args: any[]) => {
    console.error(`[ERROR] ${message}`, ...args);
  },
  debug: (message: string, ...args: any[]) => {
    console.log(`[DEBUG] ${message}`, ...args);
  },
};

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
    const uid = `corbado_${sub}`;

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
    logger.error('verifyAndMint failed:', e);
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
    logger.error('verifyCorbado failed:', e);
    throw new functions.https.HttpsError(
      'unauthenticated',
      e.message ?? 'Token verification failed'
    );
  }
});

export const mirrorCurrentLocation = onDocumentWritten(
  'users/{uid}/status/current_location',
  async (event) => {
    const db = admin.firestore();
    const uid = event.params.uid as string;
    const after = event.data?.after;

    // Validate uid to ensure it's safe for use in document paths
    if (!uid || typeof uid !== 'string') {
      logger.error(`mirrorCurrentLocation: invalid uid: ${uid}`);
      return;
    }

    // Encode the uid to make it safe for use in document paths
    const safeUid = encodeURIComponent(uid).replace(/[^a-zA-Z0-9\-_]/g, '_');

    // Create the document reference directly
    const publicDocRef = db
      .collection('public')
      .doc('current_locations')
      .collection('users')
      .doc(safeUid);

    logger.debug(
      `mirrorCurrentLocation: processing uid: ${uid}, path: ${publicDocRef.path}`
    );

    // If deleted -> remove from public
    if (!after || !after.exists) {
      await publicDocRef.delete().catch(() => {});
      logger.info(`mirrorCurrentLocation: deleted public doc for ${uid}`);
      return;
    }

    // If created or updated -> upsert public doc
    const data = after.data() ?? {};

    const lat = data.lat;
    const lng = data.lng;
    const geohash = data.geohash;
    const ts =
      data.ts && typeof data.ts.toDate === 'function'
        ? data.ts
        : admin.firestore.Timestamp.now();

    // Validate minimally to avoid poisoning public collection
    if (
      typeof lat !== 'number' ||
      typeof lng !== 'number' ||
      typeof geohash !== 'string'
    ) {
      logger.warn(
        `mirrorCurrentLocation: invalid fields for ${uid}, skipping`,
        { lat, lng, geohash }
      );
      return;
    }

    const pub = { lat, lng, geohash, ts };
    await publicDocRef.set(pub, { merge: true });
    logger.debug(`mirrorCurrentLocation: upserted public doc for ${uid}`);
  }
);
