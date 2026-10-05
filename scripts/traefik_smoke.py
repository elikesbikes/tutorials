#!/usr/bin/env python3
"""Before/after smoke test for one host's Traefik (read-only).

Usage:  traefik_smoke.py <host> [--out FILE] [--compare FILE]

Finds every address (Host rule) that the host's Traefik serves, from
  1. the traefik.http.routers.*.rule labels of the host's running containers, and
  2. the route files in the host's config/dynamic/ and config/dynamic-hosts/<host>/,
then requests each one (GET /, no redirects, TLS not verified) THROUGH that host's own
IP, and prints "address  status". Save the output before a change and compare after it:
any address whose status changed, appeared or disappeared is reported.
No credentials are sent; nothing is modified on the host.
"""
import argparse, json, re, ssl, subprocess, sys, urllib.request, urllib.error, http.client, socket

IPS = {"tars": "192.168.5.127", "endurance": "192.168.5.46", "hailmary": "192.168.5.25", "rocky": "192.168.5.28"}
HOST_RE = re.compile(r"Host\(`([^`]+)`\)")


def sh(host, cmd):
    argv = ["bash", "-c", cmd] if host == "tars" else ["ssh", "-o", "BatchMode=yes", host, cmd]
    return subprocess.run(argv, capture_output=True, text=True, timeout=60).stdout


def hosts_from_labels(host):
    out = sh(host, "docker ps -q | xargs -r docker inspect")
    names = set()
    for c in json.loads(out or "[]"):
        for k, v in (c.get("Config", {}).get("Labels") or {}).items():
            if k.startswith("traefik.http.routers.") and k.endswith(".rule"):
                names.update(HOST_RE.findall(v))
    return names


def hosts_from_files(host):
    out = sh(host, "cd ~/devops/docker/traefik/config && cat dynamic/*.yaml dynamic-hosts/%s/*.yaml 2>/dev/null" % host)
    return set(HOST_RE.findall(out))


def probe(name, ip):
    ctx = ssl.create_default_context(); ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE
    try:
        conn = http.client.HTTPSConnection(ip, 443, timeout=8, context=ctx)
        conn.request("GET", "/", headers={"Host": name, "User-Agent": "traefik-smoke"})
        return str(conn.getresponse().status)
    except (socket.timeout, TimeoutError):
        return "timeout"
    except Exception as e:                      # connection refused, TLS error, ...
        return "error:" + type(e).__name__


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("host", choices=IPS)
    ap.add_argument("--out"); ap.add_argument("--compare")
    a = ap.parse_args()
    names = sorted(hosts_from_labels(a.host) | hosts_from_files(a.host))
    result = {n: probe(n, IPS[a.host]) for n in names}
    lines = ["%s %s" % (n, s) for n, s in result.items()]
    print("\n".join(lines))
    if a.out:
        open(a.out, "w").write("\n".join(lines) + "\n")
    if a.compare:
        before = dict(l.split(" ", 1) for l in open(a.compare).read().strip().splitlines())
        diffs = [(n, before.get(n, "(absent)"), result.get(n, "(absent)")) for n in sorted(set(before) | set(result))
                 if before.get(n) != result.get(n)]
        print("\n== compared with %s: %d addresses, %d differences" % (a.compare, len(result), len(diffs)))
        for n, b, c in diffs:
            print("   CHANGED %-45s %s -> %s" % (n, b, c))
        sys.exit(1 if diffs else 0)


if __name__ == "__main__":
    main()
