#!/usr/bin/env python3
"""Eight outage-grade tasks, scored automatically, against any OpenAI-compatible chat endpoint.

The tasks are the kind the kit exists for: a shell one-liner, JSON extraction, a translation, a
small code fix, an alert summary, a tool-call JSON, a regex and mail labels. Every answer is checked
by code, so two models get the same grade for the same answer. Run it once per candidate model and
keep the numbers next to your runbook.

usage: l1bench.py <label> <base_url> [api_key] [model]
  ./bench/l1bench.py gpt-oss http://localhost:11434 "" gpt-oss:20b          # Ollama
  ./bench/l1bench.py gemma   http://localhost:8888 "$KEY" unsloth/gemma-4-26B-A4B-it-GGUF   # Unsloth
Set L1_MAX_TOKENS (default 2000) if a reasoning model spends its budget before answering.
"""
import json, os, re, subprocess, sys, tempfile, time, urllib.request

label, base = sys.argv[1], sys.argv[2].rstrip("/")
key = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else ""
model = sys.argv[4] if len(sys.argv) > 4 else None
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
os.makedirs(OUT, exist_ok=True)


def models():
    req = urllib.request.Request(f"{base}/v1/models")
    if key:
        req.add_header("Authorization", f"Bearer {key}")
    with urllib.request.urlopen(req, timeout=30) as r:
        return [m["id"] for m in json.load(r)["data"]]


def chat(prompt, max_tokens=int(os.getenv("L1_MAX_TOKENS", "2000"))):
    body = {"model": model, "messages": [{"role": "user", "content": prompt}], "temperature": 0, "max_tokens": max_tokens}
    req = urllib.request.Request(f"{base}/v1/chat/completions", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    if key:
        req.add_header("Authorization", f"Bearer {key}")
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=600) as r:
        d = json.load(r)
    dt = time.time() - t0
    text = d["choices"][0]["message"].get("content") or ""
    return text, dt, d.get("usage", {}).get("completion_tokens")


def strip_fence(t):
    m = re.search(r"```(?:\w+)?\n(.*?)```", t, re.S)
    return (m.group(1) if m else t).strip()


def first_json(t):
    t = strip_fence(t)
    m = re.search(r"\{.*\}", t, re.S)
    return json.loads(m.group(0)) if m else None


# A fixture directory for the shell task, so "the 5 largest files" has a known answer anywhere.
FIXTURE = tempfile.mkdtemp(prefix="l1bench-")
for i, size in enumerate((10, 2000, 300, 40000, 5, 900, 12000)):
    with open(os.path.join(FIXTURE, f"file{i}.dat"), "wb") as f:
        f.write(b"x" * size)
os.makedirs(os.path.join(FIXTURE, "sub"), exist_ok=True)
with open(os.path.join(FIXTURE, "sub", "deep.dat"), "wb") as f:
    f.write(b"x" * 7000)


def t_shell(ans):
    lines = [l for l in strip_fence(ans).splitlines() if l.strip()]
    if not lines:
        return False, "empty answer"
    cmd = lines[0].strip()
    r = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, timeout=60, cwd=FIXTURE)
    out = [l for l in r.stdout.splitlines() if l.strip()]
    return r.returncode == 0 and len(out) == 5 and "file3.dat" in out[0], f"rc={r.returncode} lines={len(out)} cmd={cmd[:80]}"


def t_json(ans):
    d = first_json(ans) or {}
    want = {"invoice_number": "INV-2026-0931", "date": "2026-09-30", "amount": 1842.17, "currency": "EUR"}
    got = {k: d.get(k) for k in want}
    try:
        got["amount"] = float(str(got["amount"]).replace(",", "")) if got["amount"] is not None else None
    except ValueError:
        pass
    return got == want, json.dumps(got)


def t_translate(ans):
    a = ans.lower()
    missing = [m for m in ("maintenance", "22:00", "40 minutes", "backup") if m not in a]
    return not missing, f"missing={missing}"


def t_codefix(ans):
    code = strip_fence(ans)
    test = code + "\n\nassert last_n([1,2,3,4,5], 2) == [4,5]\nassert last_n([1,2,3], 0) == []\nassert last_n([], 3) == []\nassert last_n([7], 5) == [7]\nprint('ok')\n"
    with tempfile.NamedTemporaryFile("w", suffix=".py", delete=False) as f:
        f.write(test); p = f.name
    r = subprocess.run([sys.executable, p], capture_output=True, text=True, timeout=30)
    return r.stdout.strip().endswith("ok"), (r.stderr.strip().splitlines() or ["ok"])[-1][:100]


def t_alerts(ans):
    lines = [l for l in ans.splitlines() if l.strip().startswith(("-", "*", "•", "1", "2", "3"))]
    return len(lines) == 3 and "db-primary" in lines[0].lower(), f"lines={len(lines)} first={lines[0][:60] if lines else ''}"


def t_toolcall(ans):
    d = first_json(ans) or {}
    args = d.get("arguments") or d.get("parameters") or {}
    ok = d.get("name") == "get_active_problems" and args.get("severity_min") == 4 and args.get("host_group") == "web-tier"
    return ok, json.dumps(d)[:120]


def t_regex(ans):
    pat = strip_fence(ans).splitlines()[0].strip().strip("`'\"") if strip_fence(ans).strip() else ""
    try:
        rx = re.compile(pat)
    except re.error as e:
        return False, f"bad regex: {e}"
    pos = ["2026-10-14", "1999-01-01"]; neg = ["2026-13-01", "26-10-14", "2026/10/14", "2026-10-1"]
    return all(rx.fullmatch(p) for p in pos) and not any(rx.fullmatch(n) for n in neg), pat[:60]


MAIL = [("From: App Store Connect. Subject: Your app has been rejected. Guideline 5.1.1 Privacy. Provide a privacy policy link and resubmit.", "store-compliance"),
        ("From: Hosting Provider GmbH. Subject: Invoice INV-2026-0931 for September 2026. Amount due EUR 1,842.17.", "billing"),
        ("From: JetBrains. Subject: What's new in Rider 2026.3. Read the blog post.", "newsletter"),
        ("From: Apple Support <support@apple-id-verify.example>. Subject: Your Apple ID has been locked, verify within 24 hours.", "spam")]


def t_mail(ans):
    got = re.findall(r"(store-compliance|billing|newsletter|spam)", ans.lower())[:4]
    return got == [w for _, w in MAIL], str(got)


TASKS = [
    ("shell one-liner", "Write exactly one bash command line (no explanation, no code fence) that prints the 5 largest regular files under the current directory recursively, largest first, one per line, with human-readable sizes. macOS, no GNU-only flags.", t_shell),
    ("json extraction", 'Extract from this text and answer with JSON only, keys invoice_number, date (ISO), amount (number), currency: "Hosting Provider GmbH. Invoice INV-2026-0931 dated 30 September 2026. Amount due: EUR 1,842.17, SEPA debit on 2026-10-15."', t_json),
    ("translation ru->en", "Translate to English, keep the facts exact, answer with the translation only: \"Плановое обслуживание серверов начнётся в 22:00 UTC и продлится около 40 минут; трафик будет переведён на резервные (backup) узлы автоматически.\"", t_translate),
    ("small code fix", "This Python function should return the last n items of a list (empty list for n <= 0, the whole list if n exceeds the length). It has a bug. Return only the corrected function in a code block, same name and signature.\n\ndef last_n(items, n):\n    if n <= 0:\n        return []\n    return items[-n+1:]", t_codefix),
    ("alert summary", "Summarize these monitoring problems as exactly three bullet lines, most severe first, one line each, nothing else:\n1. SSL certificate for app.example.com expires in 12 days (Warning)\n2. /var disk space critically low, 96.4% used, on db-primary-01 (Average, 1.1 GB free)\n3. High CPU over 85% for 5 minutes on web-02 (Warning, traffic normal)", t_alerts),
    ("tool-call json", 'You have a tool get_active_problems(severity_min: int, host_group: string). Produce the JSON tool call (keys "name" and "arguments", JSON only) for: list active problems of severity 4 or higher in host group "web-tier".', t_toolcall),
    ("regex", "Give one regular expression (no delimiters, no explanation, one line) that fully matches ISO dates like 2026-10-14 with a valid month 01-12 and day 01-31, and rejects 2026-13-01, 26-10-14, 2026/10/14 and 2026-10-1.", t_regex),
    ("mail labels", "Label each email with exactly one of: store-compliance, billing, newsletter, spam. Answer with four lines, label only, in order.\n\n" + "\n\n".join(f"{i+1}. {m}" for i, (m, _) in enumerate(MAIL)), t_mail),
]

if not model:
    model = models()[0]
print(f"== {label}: model={model} base={base}")
chat("Reply with OK.", max_tokens=5)  # warm-up: the first task should not pay the model load
rows = []
for name, prompt, check in TASKS:
    try:
        ans, dt, toks = chat(prompt)
        ok, note = check(ans)
    except Exception as e:
        ans, dt, toks, ok, note = "", 0.0, None, False, f"error: {str(e)[:80]}"
    rows.append({"task": name, "ok": ok, "s": round(dt, 1), "tokens": toks, "note": note, "answer": ans[:600]})
    print(f"  {'ok ' if ok else 'XX '} {name:<18} {dt:5.1f} s  {note[:90]}")
score = sum(r["ok"] for r in rows)
tot = sum(r["s"] for r in rows)
tps = [r["tokens"] / r["s"] for r in rows if r["tokens"] and r["s"] > 0]
print(f"  score {score}/{len(TASKS)}, total {tot:.0f} s, ~{(sum(tps) / len(tps)) if tps else 0:.0f} tok/s")
json.dump({"label": label, "model": model, "score": score, "total_s": round(tot), "rows": rows},
          open(os.path.join(OUT, f"{label}.json"), "w"), indent=1)
