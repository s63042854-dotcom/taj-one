#!/usr/bin/env bash
set -uo pipefail
PROJECT=taj-one-23c1c
KEY=AIzaSyDsMizmao4lqzaP_x8DTpzy8nLduWCOnvc
python3 - "$PROJECT" "$KEY" <<'PY'
import json, subprocess, sys, urllib.request
p, key = sys.argv[1], sys.argv[2]
tok = subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()
H = {"Authorization": "Bearer " + tok, "Content-Type": "application/json"}
def call(url, data=None, method=None):
    req = urllib.request.Request(url, data=data, method=method, headers=H)
    return json.load(urllib.request.urlopen(req))

rel = call("https://firebaserules.googleapis.com/v1/projects/%s/releases/cloud.firestore" % p)
rid = rel.get("rulesetName", "").split("/")[-1]
print("RULES_RELEASE:", rid, rel.get("updateTime", ""))
rs = call("https://firebaserules.googleapis.com/v1/projects/%s/rulesets/%s" % (p, rid))
files = rs.get("source", {}).get("files", [])
body = files[0]["content"] if files else ""
print("HAS_AUTO_RULE:", "match /taj/auto" in body)
print("HAS_SIG_CHECK:", "sig" in body)

base = "https://apikeys.googleapis.com/v2/projects/%s/locations/global/keys" % p
ks = call(base).get("keys", [])
target = None
for k in ks:
    d = call(base + "/" + k["name"].split("/")[-1])
    if d.get("keyString") == key:
        target = d
        break
if not target:
    print("KEY_NOT_FOUND")
    raise SystemExit(0)
before = [t.get("service") for t in target.get("restrictions", {}).get("apiTargets", [])]
print("KEY_BEFORE:", before or "UNRESTRICTED")
if before:
    print("KEY_ALREADY_RESTRICTED")
    raise SystemExit(0)
want = ["firestore.googleapis.com", "identitytoolkit.googleapis.com", "securetoken.googleapis.com"]
body = json.dumps({"restrictions": {"apiTargets": [{"service": s} for s in want]}}).encode()
upd = call(base + "/" + target["name"].split("/")[-1] + "?updateMask=restrictions", body, "PATCH")
print("KEY_AFTER:", [t.get("service") for t in upd.get("restrictions", {}).get("apiTargets", [])])
print("DONE")
PY
