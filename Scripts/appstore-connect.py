"""Minimal App Store Connect API client.

Used to create the app's in-app purchases. Kept because pricing and product changes are
easier to review as a script than as a series of clicks, and because the subscription
pricing endpoint currently rejects valid price points (see docs/APP_STORE.md section 5),
which is the sort of thing worth being able to retry quickly.


No PyJWT or cryptography on this machine, so the ES256 token is signed with the openssl
CLI and the DER signature converted to the raw r||s form JOSE requires.
"""
import base64, json, subprocess, time, urllib.request, urllib.error, os, sys

# Read from the environment: this repo is public, and while a Key ID and Issuer ID are
# useless without the .p8, there is no reason to publish them.
#
#   export ASC_KEY_ID=XXXXXXXXXX
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# The private key lives at ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8 (chmod 600).
KEY_ID = os.environ.get("ASC_KEY_ID", "")
ISSUER_ID = os.environ.get("ASC_ISSUER_ID", "")
KEY_PATH = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8")
BASE = "https://api.appstoreconnect.apple.com"


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _der_to_jose(der: bytes) -> bytes:
    """SEQUENCE { INTEGER r, INTEGER s } -> 32-byte r || 32-byte s."""
    assert der[0] == 0x30
    idx = 2 if der[1] < 0x80 else 3 + (der[1] & 0x7F) - 1
    out = b""
    for _ in range(2):
        assert der[idx] == 0x02
        length = der[idx + 1]
        val = der[idx + 2: idx + 2 + length].lstrip(b"\x00")
        out += val.rjust(32, b"\x00")
        idx += 2 + length
    return out


def token() -> str:
    if not KEY_ID or not ISSUER_ID:
        raise SystemExit("set ASC_KEY_ID and ASC_ISSUER_ID (see the note at the top)")
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    now = int(time.time())
    payload = {"iss": ISSUER_ID, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    signing_input = f"{_b64(json.dumps(header).encode())}.{_b64(json.dumps(payload).encode())}"
    der = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", KEY_PATH],
        input=signing_input.encode(), capture_output=True, check=True,
    ).stdout
    return f"{signing_input}.{_b64(_der_to_jose(der))}"


def request(method: str, path: str, body=None):
    url = path if path.startswith("http") else BASE + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", f"Bearer {token()}")
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            return resp.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as e:
        raw = e.read()
        try:
            return e.code, json.loads(raw)
        except Exception:
            return e.code, {"raw": raw.decode(errors="replace")}


def errors(payload) -> str:
    return "; ".join(
        f"{e.get('title')}: {e.get('detail')}" for e in payload.get("errors", [])
    ) or json.dumps(payload)[:400]
