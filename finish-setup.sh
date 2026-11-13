#!/usr/bin/env bash
set -uo pipefail
PROJECT=taj-one-23c1c
KEY=AIzaSyDsMizmao4lqzaP_x8DTpzy8nLduWCOnvc
python3 - "$PROJECT" "$KEY" <<'PY'
import json, subprocess, sys, urllib.request
p, key = sys.argv[1], sys.argv[2]
tok = subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()
H = {"Authorization": "Bearer " + tok, "Content-Type": "application/json"}
out = {}
def call(url, data=None, method=None):
    req = urllib.request.Request(url, data=data, method=method, headers=H)
    return json.load(urllib.request.urlopen(req))
try:
    rel = call("https://firebaserules.googleapis.com/v1/projects/%s/releases/cloud.firestore" % p)
    rid = rel.get("rulesetName", "").split("/")[-1]
    rs = call("https://firebaserules.googleapis.com/v1/projects/%s/rulesets/%s" % (p, rid))
    files = rs.get("source", {}).get("files", [])
    body = files[0]["content"] if files else ""
    out["rules"] = "ok"
    out["auto_rule"] = "match /taj/auto" in body
    out["sig_rule"] = "sig" in body
    base = "https://apikeys.googleapis.com/v2/projects/%s/locations/global/keys" % p
    ks = call(base).get("keys", [])
    target = None
    for k in ks:
        d = call(base + "/" + k["name"].split("/")[-1])
        if d.get("keyString") == key:
            target = d
            break
    if not target:
        out["key"] = "not_found"
    else:
        before = [t.get("service") for t in target.get("restrictions", {}).get("apiTargets", [])]
        out["key_before"] = before or "unrestricted"
        if before:
            out["key_after"] = before
        else:
            want = ["firestore.googleapis.com", "identitytoolkit.googleapis.com", "securetoken.googleapis.com"]
            bodyj = json.dumps({"restrictions": {"apiTargets": [{"service": s} for s in want]}}).encode()
            upd = call(base + "/" + target["name"].split("/")[-1] + "?updateMask=restrictions", bodyj, "PATCH")
            out["key_after"] = [t.get("service") for t in upd.get("restrictions", {}).get("apiTargets", [])]
except Exception as e:
    out["error"] = type(e).__name__ + ": " + str(e)[:120]
print("SUMMARY: " + json.dumps(out, ensure_ascii=False))
PY
