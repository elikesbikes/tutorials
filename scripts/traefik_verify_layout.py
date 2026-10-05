#!/usr/bin/env python3
"""Offline check: does the desired Traefik layout (infra/traefik) equal what a host runs?

Usage: traefik_verify_layout.py [host ...]        (default: tars endurance hailmary rocky)

"What a host runs" = its snapshot in infra-snapshots/traefik/<host>/ (made by snapshot-traefik.sh).
"Desired"          = infra/traefik/shared + infra/traefik/hosts/<host>.
Compares, per host:
  1. dynamic config: every http/tcp/tls object (routers, services, middlewares, ...) from the files the
     container loads (shared dir + this host's dir). Duplicate names across files are errors.
  2. static config (traefik.yaml)
  3. the compose file as Docker renders it (docker compose config) with a synthetic .env.
Nothing is read from or written to a host. Exit code 1 if any difference is not listed in EXPECTED.
"""
import json, subprocess, sys, tempfile, shutil
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parent.parent
SNAP = ROOT / "infra-snapshots/traefik"
NEW = ROOT / "infra/traefik"
HOSTS = ["tars", "endurance", "hailmary", "rocky"]

# Differences we KNOW about and want (anything else is a failure).
EXPECTED = {
    "static": {"tars": ["entryPoints.proton-imaps", "entryPoints.proton-smtps"],
               "endurance": ["entryPoints.proton-imaps", "entryPoints.proton-smtps"],
               "rocky": ["entryPoints.proton-imaps", "entryPoints.proton-smtps"]},
}
SYNTH_ENV = ("TRAEFIK_DASHBOARD_HOST=proxy-%(h)s.example\nPUID=1000\nPGID=1000\nTZ=America/Los_Angeles\n"
             "SYSLOG_ADDRESS=udp://192.168.5.25:514\nPROXY_HOST=%(h)s\nCF_DNS_API_TOKEN=dummy\n")


def merge_dynamic(files):
    merged, dups = {}, []
    for f in sorted(files):
        doc = yaml.safe_load(f.read_text()) or {}
        for proto, sections in doc.items():
            for section, objs in (sections or {}).items():
                for name, obj in (objs or {}).items():
                    key = (proto, section, name)
                    if key in merged:
                        dups.append("%s.%s.%s (again in %s)" % (proto, section, name, f.name))
                    merged[key] = obj
    return merged, dups


def flat(d, prefix=""):
    out = {}
    for k, v in (d or {}).items():
        p = prefix + k
        if isinstance(v, dict):
            out.update(flat(v, p + "."))
        else:
            out[p] = json.dumps(v, sort_keys=True)
    return out


def render_compose(base_dir, files, host):
    tmp = Path(tempfile.mkdtemp())
    try:
        for name, src in files.items():
            shutil.copy(src, tmp / name)
        (tmp / ".env").write_text(SYNTH_ENV % {"h": host})
        args = ["docker", "compose", "--project-name", "traefik-verify", "--project-directory", str(tmp)]
        for name in files:
            args += ["-f", str(tmp / name)]
        args += ["--env-file", str(tmp / ".env"), "config", "--format", "json"]
        out = subprocess.run(args, capture_output=True, text=True)
        if out.returncode:
            raise SystemExit("compose render failed: " + out.stderr[:300])
        return json.loads(out.stdout.replace(str(tmp), "<dir>"))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    hosts = sys.argv[1:] or HOSTS
    bad = 0
    for h in hosts:
        print("=== %s" % h)
        # 1. dynamic
        live_files = list((SNAP / h / "config/dynamic").glob("*.yaml")) + list((SNAP / h / "config/dynamic-hosts" / h).glob("*.yaml"))
        new_files = list((NEW / "shared/config/dynamic").glob("*.yaml")) + list((NEW / "hosts" / h / "config/dynamic-hosts" / h).glob("*.yaml"))
        live, ld = merge_dynamic(live_files); new, nd = merge_dynamic(new_files)
        diffs = [("only live", k) for k in live if k not in new] + [("only new", k) for k in new if k not in live] \
              + [("different", k) for k in live if k in new and live[k] != new[k]]
        print("  dynamic : %d objects live, %d new, duplicates live/new: %d/%d, differences: %d" % (len(live), len(new), len(ld), len(nd), len(diffs)))
        for d in diffs + [("duplicate in new", x) for x in nd]:
            print("     !!", d); bad += 1
        # 2. static
        ls = flat(yaml.safe_load((SNAP / h / "config/traefik.yaml").read_text()))
        ns = flat(yaml.safe_load((NEW / "shared/config/traefik.yaml").read_text()))
        sdiff = sorted({k for k in set(ls) | set(ns) if ls.get(k) != ns.get(k)})
        exp = EXPECTED["static"].get(h, [])
        unexpected = [k for k in sdiff if not any(k == e or k.startswith(e + ".") for e in exp)]
        print("  static  : %d differing keys (%d expected: %s)" % (len(sdiff), len(sdiff) - len(unexpected), ", ".join(exp) or "none"))
        for k in unexpected:
            print("     !!", k, ls.get(k), "->", ns.get(k)); bad += 1
        # 3. compose as rendered
        lf = {"docker-compose.yml": SNAP / h / "docker-compose.yml"}
        nf = {"docker-compose.yml": NEW / "shared/docker-compose.yml"}
        ov = NEW / "hosts" / h / "docker-compose.override.yml"
        if ov.exists():
            nf["docker-compose.override.yml"] = ov
        lc, nc = flat(render_compose(None, lf, h)), flat(render_compose(None, nf, h))
        cdiff = sorted({k for k in set(lc) | set(nc) if lc.get(k) != nc.get(k)})
        print("  compose : %d rendered differences (with SYSLOG_ADDRESS set as on the real hosts)" % len(cdiff))
        for k in cdiff:
            print("     !!", k, lc.get(k), "->", nc.get(k)); bad += 1
    print("\nRESULT:", "ALL EQUIVALENT (apart from the expected static entry points)" if not bad else "%d UNEXPECTED DIFFERENCES" % bad)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
