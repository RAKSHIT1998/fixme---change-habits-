#!/usr/bin/env python3
"""Generate the public website (legal + support) from the in-app text.

App Store review compares the policy you host against what the app shows, so the two
must not drift. LegalDocuments.swift stays the single source of truth for Privacy and
Terms, and this regenerates docs/ from it. Re-run after editing the Swift file.

    python3 Scripts/generate-legal-html.py                  # relative links, no CNAME
    python3 Scripts/generate-legal-html.py --domain fixme.app

Pages produced in docs/:
    index.html    landing page (App Store Connect "Marketing URL")
    privacy.html  Privacy Policy   (required: "Privacy Policy URL")
    terms.html    Terms of Use / EULA
    support.html  Support + FAQ    (required: "Support URL")
    404.html, .nojekyll, CNAME (with --domain)
"""
import argparse
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "FixMe/Features/Legal/LegalDocuments.swift"
OUT = ROOT / "docs"

SUPPORT_EMAIL = "rakshitbargotra@gmail.com"

SECTION_RE = re.compile(
    r'LegalSection\(\s*heading:\s*"(?P<heading>[^"]+)",\s*body:\s*"""(?P<body>.*?)"""\s*\)',
    re.DOTALL,
)


def sections(block: str):
    """Parse LegalSection(...) entries, unwrapping Swift's trailing-backslash line joins."""
    found = []
    for match in SECTION_RE.finditer(block):
        body = match.group("body")
        body = re.sub(r"\\\n\s*", " ", body)          # Swift line continuations
        paragraphs = [
            " ".join(line.strip() for line in para.strip().splitlines()).strip()
            for para in body.split("\n\n")
        ]
        found.append((match.group("heading"), [p for p in paragraphs if p]))
    return found


def slice_between(text, start_marker, end_marker):
    start = text.index(start_marker)
    end = text.index(end_marker, start) if end_marker else len(text)
    return text[start:end]


STYLE = """
  :root { color-scheme: light dark; --accent:#F2551F; --fg:#141414; --muted:#5c5c62;
          --bg:#fff; --card:#f7f6f4; --rule:rgba(128,128,128,.22); }
  @media (prefers-color-scheme: dark) {
    :root { --fg:#f2f2f2; --muted:#a6a6ad; --bg:#0b0b0d; --card:#16161a; }
  }
  * { box-sizing: border-box; }
  body { margin:0; background:var(--bg); color:var(--fg);
         font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         -webkit-font-smoothing: antialiased; }
  .wrap { max-width: 46rem; margin: 0 auto; padding: 2.6rem 1.25rem 5rem; }
  .brand { font-weight:800; letter-spacing:.08em; font-size:.78rem; color:var(--accent);
           text-decoration:none; display:inline-block; }
  h1 { font-size: clamp(1.9rem, 5vw, 2.6rem); line-height:1.15; margin:.4rem 0 .2rem;
       letter-spacing:-.02em; }
  .updated, .lede { color:var(--muted); font-size:.9rem; margin-bottom:2.2rem; }
  .lede { font-size:1.05rem; max-width:34rem; }
  h2 { font-size:1.12rem; margin:2.1rem 0 .5rem; letter-spacing:-.01em; }
  h3 { font-size:1rem; margin:1.5rem 0 .3rem; }
  p { margin:.55rem 0; color:var(--muted); }
  ul { color:var(--muted); padding-left:1.15rem; margin:.55rem 0; }
  li { margin:.3rem 0; }
  a { color:var(--accent); }
  strong { color:var(--fg); font-weight:600; }
  .card { background:var(--card); border-radius:14px; padding:1.1rem 1.25rem; margin:1.4rem 0; }
  .card p:first-child { margin-top:0; }
  .card p:last-child { margin-bottom:0; }
  .links a { display:block; padding:.95rem 0; font-weight:600; text-decoration:none;
             border-top:1px solid var(--rule); }
  nav { margin:2.4rem 0 0; font-size:.86rem; }
  nav a { margin-right:1.1rem; text-decoration:none; }
  footer { margin-top:3rem; padding-top:1.2rem; border-top:1px solid var(--rule);
           color:var(--muted); font-size:.82rem; }
  footer a { color:var(--accent); }
"""

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{description}">
<style>{style}</style>
</head>
<body>
<div class="wrap">
  <a class="brand" href="./">FIX ME</a>
  <h1>{heading}</h1>
  {subhead}
{body}
  <nav>{nav}</nav>
  <footer>{footer}</footer>
</div>
</body>
</html>
"""

NAV = ('<a href="./">Home</a><a href="./privacy.html">Privacy</a>'
       '<a href="./terms.html">Terms</a><a href="./support.html">Support</a>')

FOOTER = ('Fix Me — 90 days. Better habits. Better you.<br>'
          'Questions: <a href="mailto:{email}">{email}</a>')


def page(*, title, heading, description, body, subhead="", nav=NAV):
    return PAGE.format(
        title=title, heading=heading, description=description, style=STYLE,
        subhead=subhead, body=body, nav=nav,
        footer=FOOTER.format(email=SUPPORT_EMAIL),
    )


INDEX_BODY = """
  <p class="lede">A 90-day habit tracker for iPhone. Build the habits you want, quit the
  ones you don't, and prove you showed up — with everything stored on your own device.</p>

  <div class="card">
    <p><strong>No account. No server. No tracking.</strong> Fix Me has no sign-up, stores your
    habits, photos and journals on your iPhone, and includes no analytics, advertising or
    tracking SDKs of any kind.</p>
  </div>

  <h2>What it does</h2>
  <ul>
    <li><strong>90-day journey</strong> — pick your habits and run them for a full 90 days.</li>
    <li><strong>Quit tracking</strong> — clean time, money saved, cravings resisted and a
    recovery timeline. Never paywalled.</li>
    <li><strong>PROVE IT</strong> — photo verification analysed on-device with Apple's Vision
    framework. The photo never leaves your phone.</li>
    <li><strong>Apple Health</strong> — step and workout habits complete themselves.</li>
    <li><strong>Alarms</strong> — reminders with a Done button on the lock screen.</li>
    <li><strong>Friends</strong> — paired phone-to-phone over Bluetooth/Wi-Fi or a signed
    invite link. No accounts, no directory, no server in between.</li>
  </ul>

  <h2>Legal &amp; support</h2>
  <div class="links">
    <a href="./privacy.html">Privacy Policy →</a>
    <a href="./terms.html">Terms of Use →</a>
    <a href="./support.html">Support &amp; FAQ →</a>
  </div>
"""

SUPPORT_BODY = """
  <p class="lede">Something broken, a question, or a refund to chase? Start here.</p>

  <div class="card">
    <p><strong>Email:</strong> <a href="mailto:{email}">{email}</a></p>
    <p>One person answers these, usually within a few days. Including your iPhone model, iOS
    version and what you were doing when it went wrong makes a fix far more likely.</p>
  </div>

  <h2>Common questions</h2>

  <h3>How do I cancel my subscription or get a refund?</h3>
  <p>Subscriptions are billed by Apple, not by us. Cancel in <strong>Settings › your name ›
  Subscriptions</strong> on your iPhone, or at
  <a href="https://apps.apple.com/account/subscriptions">apps.apple.com/account/subscriptions</a>.
  Cancel at least 24 hours before the renewal date to avoid being charged for the next period.
  Refunds are handled entirely by Apple at
  <a href="https://reportaproblem.apple.com">reportaproblem.apple.com</a> — we cannot issue them.</p>

  <h3>I paid but Premium isn't showing up.</h3>
  <p>Open <strong>Profile › Settings › Restore purchases</strong> while signed in to the same
  Apple Account you bought with. If it still doesn't unlock, email us the date of purchase and
  we'll help.</p>

  <h3>I got a new phone. Where is my data?</h3>
  <p>Your data lives on your device, not on a server, so it moves with an encrypted iPhone
  backup or a direct device-to-device transfer. It does not sync between two phones, and if you
  delete the app without a backup it's gone. <strong>Profile › Settings › Export my data</strong>
  writes a JSON copy you can keep.</p>

  <h3>How do I delete my data?</h3>
  <p>There is no account to delete — we hold nothing about you. On your device:
  <strong>Profile › Settings › Delete my photos</strong> removes every verification and daily
  photo, and <strong>Delete my data</strong> erases habits, history, journals, streaks and
  friends. Deleting the app removes all of it too.</p>

  <h3>My alarm didn't go off.</h3>
  <p>iOS does not let any third-party app ring through Silent mode or a Focus without Apple's
  Critical Alerts entitlement. Fix Me alarms are Time Sensitive notifications, which break
  through most Focus modes but not all of them. For anything you genuinely cannot miss, keep a
  backup alarm in Apple's Clock app. Also check <strong>Settings › Notifications › Fix Me</strong>
  is allowed and Time Sensitive notifications are on.</p>

  <h3>Health habits aren't completing automatically.</h3>
  <p>Open the <strong>Health</strong> app › <strong>Sharing</strong> › <strong>Apps</strong> ›
  <strong>Fix Me</strong> and confirm steps, workouts, exercise and sleep are enabled. Without
  permission those habits fall back to manual completion; nothing else changes.</p>

  <h3>PROVE IT rejected a real photo.</h3>
  <p>Verification is an on-device estimate from Apple's Vision framework — it can be wrong in
  both directions and is evidence, not proof. Better light and a clearer subject help. It never
  uploads your photo.</p>

  <h3>Adding a friend isn't working.</h3>
  <p>Nearby pairing needs both phones awake, on the same Wi-Fi or with Bluetooth on, and Fix Me
  open on the pairing screen on both. At a distance, use the invite link instead — send it
  through any messaging app. Because there is no server, nobody can push updates to a sleeping
  phone; open the app now and then to see what your friends have sent.</p>

  <h3>Is my data used to train anything, or sold?</h3>
  <p>No. Nothing leaves your device except what you explicitly send to a friend or share
  yourself. See the <a href="./privacy.html">Privacy Policy</a>.</p>

  <h2>Health and safety</h2>
  <p>Fix Me is a habit tracker, not a medical device, and gives no medical advice. If you drink
  heavily or daily, stopping suddenly can be dangerous — talk to a doctor first. In an
  emergency, call your local emergency number.</p>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--domain", help="custom domain to write into docs/CNAME, e.g. fixme.app")
    args = parser.parse_args()

    if not SOURCE.exists():
        print(f"error: {SOURCE} not found", file=sys.stderr)
        return 1
    text = SOURCE.read_text()

    updated_match = re.search(r'var lastUpdated: String \{ "([^"]+)" \}', text)
    updated = updated_match.group(1) if updated_match else "—"

    documents = {
        "privacy": ("Privacy Policy",
                    slice_between(text, "private static let privacySections", "// MARK: - Terms")),
        "terms": ("Terms of Use",
                  slice_between(text, "private static let termsSections", "struct LegalSection")),
    }

    OUT.mkdir(exist_ok=True)
    for name, (title, block) in documents.items():
        parsed = sections(block)
        if not parsed:
            print(f"error: parsed 0 sections for {name} — check LegalDocuments.swift format",
                  file=sys.stderr)
            return 1
        body = "\n".join(
            f"  <h2>{heading}</h2>\n" + "\n".join(f"  <p>{p}</p>" for p in paras)
            for heading, paras in parsed
        )
        (OUT / f"{name}.html").write_text(page(
            title=f"{title} — Fix Me",
            heading=title,
            description=f"{title} for the Fix Me iPhone app.",
            subhead=f'<div class="updated">Last updated {updated} · mirrors the {title} '
                    f'shown inside the app</div>',
            body=body,
        ))
        print(f"wrote docs/{name}.html  ({len(parsed)} sections)")

    (OUT / "support.html").write_text(page(
        title="Support — Fix Me",
        heading="Support",
        description="Help, FAQ and contact for the Fix Me iPhone app.",
        body=SUPPORT_BODY.format(email=SUPPORT_EMAIL),
    ))
    print("wrote docs/support.html")

    (OUT / "index.html").write_text(page(
        title="Fix Me — 90-day habit tracker for iPhone",
        heading="Fix Me",
        description="A 90-day habit tracker for iPhone. No account, no server, "
                    "everything stays on your device.",
        body=INDEX_BODY,
        nav='<a href="./privacy.html">Privacy</a><a href="./terms.html">Terms</a>'
            '<a href="./support.html">Support</a>',
    ))
    print("wrote docs/index.html")

    (OUT / "404.html").write_text(page(
        title="Not found — Fix Me",
        heading="Not found",
        description="Page not found.",
        body='  <p>That page doesn\'t exist. Try the links below.</p>\n'
             '  <div class="links">\n'
             '    <a href="./">Home →</a>\n'
             '    <a href="./privacy.html">Privacy Policy →</a>\n'
             '    <a href="./terms.html">Terms of Use →</a>\n'
             '    <a href="./support.html">Support →</a>\n  </div>',
    ))
    print("wrote docs/404.html")

    (OUT / ".nojekyll").write_text("")   # stop GitHub Pages from reprocessing these files
    print("wrote docs/.nojekyll")

    if args.domain:
        (OUT / "CNAME").write_text(args.domain.strip() + "\n")
        print(f"wrote docs/CNAME  ({args.domain.strip()})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
