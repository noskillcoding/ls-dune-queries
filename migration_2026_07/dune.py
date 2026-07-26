#!/usr/bin/env python3
"""Dune API helper for reviving the loot-survivor-2 dashboard.

Two keys, two roles:
  WRITE_KEY (personal, lowskillcoding) - owns the 25 dashboard queries, so it is the
      only key that can PATCH / archive / unarchive them. Free plan: rejects an
      explicit performance tier and has a smaller credit pool.
  EXEC_KEY  (team, lootsurvivor) - the PAID plan. Used for every execution so runs
      get the 'medium' performance tier and draw on the 4000-credit pool. It can
      execute the personal queries because they are public.

Set both keys in the environment before use -- they are deliberately NOT hardcoded:

    export DUNE_WRITE_KEY=...   # personal account key (owns the queries)
    export DUNE_EXEC_KEY=...    # team key, paid plan (used for executions)

If DUNE_EXEC_KEY is unset it falls back to DUNE_WRITE_KEY, which still works but runs
executions on the personal plan (no explicit performance tier allowed there).
"""
import json, os, sys, time, urllib.request, urllib.error

WRITE_KEY = os.environ.get("DUNE_WRITE_KEY")
EXEC_KEY = os.environ.get("DUNE_EXEC_KEY") or WRITE_KEY
if not WRITE_KEY:
    raise SystemExit(
        "DUNE_WRITE_KEY is not set.\n"
        "  export DUNE_WRITE_KEY=<personal Dune API key>\n"
        "  export DUNE_EXEC_KEY=<team Dune API key>   # optional, for the paid plan"
    )
BASE = "https://api.dune.com/api/v1"


def req(path, data=None, method=None, key=None):
    body = json.dumps(data).encode() if data is not None else None
    r = urllib.request.Request(
        f"{BASE}{path}", data=body,
        headers={"X-Dune-Api-Key": key or WRITE_KEY, "Content-Type": "application/json"},
        method=method,
    )
    try:
        return json.loads(urllib.request.urlopen(r).read().decode())
    except urllib.error.HTTPError as e:
        return {"_http": e.code, "_body": e.read().decode()[:300]}


# ---- metadata / writes: personal key ----
def meta(qid, key=None):
    return req(f"/query/{qid}", key=key)


def patch(qid, **kw):
    return req(f"/query/{qid}", data=kw, method="PATCH", key=WRITE_KEY)


def unarchive(qid):
    return req(f"/query/{qid}/unarchive", data={}, method="POST", key=WRITE_KEY)


def archive(qid):
    return req(f"/query/{qid}/archive", data={}, method="POST", key=WRITE_KEY)


def create(name, sql, description="", private=False, key=None):
    return req("/query", data={"name": name, "query_sql": sql,
                               "description": description, "is_private": private},
               key=key or WRITE_KEY)


# ---- executions: team (paid) key ----
def run(qid, perf="medium", timeout=1200, key=None):
    k = key or EXEC_KEY
    ex = req(f"/query/{qid}/execute",
             data={} if perf is None else {"performance": perf}, key=k)
    eid = ex.get("execution_id")
    if not eid:
        return {"state": "SUBMIT_FAILED", "raw": ex}
    t0 = time.time()
    while time.time() - t0 < timeout:
        time.sleep(5)
        s = req(f"/execution/{eid}/status", key=k)
        st = s.get("state", "")
        if st in ("QUERY_STATE_COMPLETED", "QUERY_STATE_FAILED", "QUERY_STATE_CANCELLED"):
            s["_eid"] = eid
            return s
    return {"state": "TIMEOUT", "_eid": eid}


def results(eid, limit=1000, key=None):
    return req(f"/execution/{eid}/results?limit={limit}", key=key or EXEC_KEY)


def run_sql(sql, qid=None, name="ZZ-tmp-claude-probe", perf="medium", limit=1000):
    """Ad-hoc SQL via a scratch query (Dune has no ad-hoc SQL endpoint)."""
    if qid is None:
        c = create(name, sql, key=EXEC_KEY)
        qid = c.get("query_id")
        if not qid:
            return {"error": "create failed", "raw": c}
    else:
        r = req(f"/query/{qid}", data={"query_sql": sql}, method="PATCH", key=EXEC_KEY)
        if r.get("_http"):
            return {"error": "patch failed", "raw": r}
    st = run(qid, perf=perf)
    out = {"qid": qid, "state": st.get("state")}
    if st.get("state") != "QUERY_STATE_COMPLETED":
        out["error"] = st.get("error") or st
        return out
    r = results(st["_eid"], limit=limit)
    out["rows"] = r.get("result", {}).get("rows", [])
    out["row_count"] = r.get("result", {}).get("metadata", {}).get("total_row_count")
    return out


def usage(key=None):
    return req("/usage", data={}, method="POST", key=key or EXEC_KEY)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "meta":
        m = meta(sys.argv[2]); m.pop("query_sql", None); print(json.dumps(m, indent=1))
    elif cmd == "sql":
        print(meta(sys.argv[2]).get("query_sql", ""))
    elif cmd == "run":
        print(json.dumps(run(sys.argv[2]), indent=1))
    elif cmd == "usage":
        print("team:    ", json.dumps(usage(EXEC_KEY)))
        print("personal:", json.dumps(usage(WRITE_KEY)))
