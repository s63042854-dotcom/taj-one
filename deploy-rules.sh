#!/usr/bin/env bash
set -euo pipefail
PROJECT=taj-one-23c1c
RAW=https://raw.githubusercontent.com/s63042854-dotcom/taj-one/main
curl -fsSL "$RAW/firestore.rules" -o /tmp/firestore.rules
python3 - "$PROJECT" <<'PY'
import json, subprocess, sys, urllib.request
p = sys.argv[1]
tok = subprocess.check_output(["gcloud", "auth", "print-access-token"], text=True).strip()
src = open("/tmp/firestore.rules").read()
def call(url, data=None, method=None):
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Authorization": "Bearer " + tok,
                                          "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))
rs = call("https://firebaserules.googleapis.com/v1/projects/%s/rulesets" % p,
          json.dumps({"source": {"files": [{"name": "firestore.rules", "content": src}]}}).encode(), "POST")
print("RULESET:", rs["name"])
rel = call("https://firebaserules.googleapis.com/v1/projects/%s/releases/cloud.firestore" % p,
           json.dumps({"release": {"name": "projects/%s/releases/cloud.firestore" % p,
                                   "rulesetName": rs["name"]}}).encode(), "PATCH")
print("RELEASE:", rel.get("name"), "->", rel.get("rulesetName"))
print("DONE")
PY
