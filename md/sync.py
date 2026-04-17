#!/usr/bin/env python3
import gzip
import json
import os
import re
import sys
import urllib.request

TEAM = "ethpandaops"
API = f"https://notes.ethereum.org/api/OpenAPI/v1/teams/{TEAM}/notes"
UA = "curl/8.4.0"

PR_RE = re.compile(
    r"(\[PR-\d+[^\]]*\]\(https://github\.com/([^/\s]+)/([^/\s)]+)/pull/(\d+)\))"
    r"(?:[ \t]+(?:Merged|Open|Closed|Draft))?(?:[ \t]+:[\w_]+:)?"
    r"(?=[ \t]*(?:~~|$))",
    re.MULTILINE,
)

PR_URL_RE = re.compile(r"https://github\.com/([^/]+)/([^/]+)/pull/(\d+)(?:[/?#].*)?$")
PR_LINE_RE = re.compile(
    r"^\s*-\s*\[PR-\d+[^\]]*\]\(https://github\.com/([^/\s]+)/([^/\s)]+)/pull/(\d+)\)"
)

STATUS_LABEL = {
    "merged": "Merged :heavy_check_mark:",
    "closed": "Closed :x:",
    "draft": "Draft :exclamation:",
    "open": "Open :exclamation:",
}

REPO_SECTIONS = {
    ("ethereum", "beacon-APIs"): "Beacon API",
    ("ethereum", "builder-specs"): "Builder Specs",
    ("ethereum", "consensus-specs"): "Consensus Specs",
    ("ethereum", "EIPs"): "EIPs",
    ("ethereum", "execution-apis"): "Execution APIs",
    ("ethereum", "execution-specs"): "Execution Spec PRs",
}


def hackmd(method, path="", body=None):
    headers = {
        "Authorization": f"Bearer {os.environ['HACKMD_TOKEN']}",
        "Content-Type": "application/json",
        "User-Agent": UA,
    }
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        if len(data) > 8000:
            data = gzip.compress(data)
            headers["Content-Encoding"] = "gzip"
    req = urllib.request.Request(
        f"{API}/{path}" if path else API,
        data=data,
        headers=headers,
        method=method,
    )
    return urllib.request.urlopen(req)


def github_pr(owner, repo, num):
    req = urllib.request.Request(
        f"https://api.github.com/repos/{owner}/{repo}/pulls/{num}",
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": UA,
            **(
                {"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"}
                if os.environ.get("GITHUB_TOKEN")
                else {}
            ),
        },
    )
    return json.loads(urllib.request.urlopen(req).read())


def status_from_pr(pr):
    if pr.get("merged"):
        return STATUS_LABEL["merged"]
    if pr["state"] == "closed":
        return STATUS_LABEL["closed"]
    if pr.get("draft"):
        return STATUS_LABEL["draft"]
    return STATUS_LABEL["open"]


def find_note_id(network):
    for n in json.loads(hackmd("GET").read()):
        if n.get("permalink") == network:
            return n["id"]
    raise SystemExit(f"no note with permalink '{network}' in team {TEAM}")


def local_path(network):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), f"{network}.md")


def pull(network):
    note = json.loads(hackmd("GET", find_note_id(network)).read())
    with open(local_path(network), "w") as f:
        f.write(note["content"])
    print(f"pulled {network}.md ({len(note['content'])} bytes)")


def push(network):
    with open(local_path(network)) as f:
        content = f.read()
    resp = hackmd("PATCH", find_note_id(network), {"content": content})
    print(f"pushed {network}.md -> HTTP {resp.status}")


def sync_prs(network):
    path = local_path(network)
    with open(path) as f:
        text = f.read()
    cache = {}

    def replace(m):
        link, owner, repo, num = m.group(1), m.group(2), m.group(3), m.group(4)
        old_status = m.group(0)[len(link):].strip()
        key = (owner, repo, num)
        if key not in cache:
            cache[key] = status_from_pr(github_pr(owner, repo, int(num)))
        new_status = cache[key]
        if old_status != new_status:
            print(f"{owner}/{repo}#{num}: {old_status or '(none)'} -> {new_status}")
        return f"{link} {new_status}"

    new_text = PR_RE.sub(replace, text)
    if new_text == text:
        print(f"{network}.md: no changes")
        return
    with open(path, "w") as f:
        f.write(new_text)
    print(f"updated {network}.md")
    push(network)


def add_pr(network, *args):
    if len(args) == 1:
        sync_remote, url = False, args[0]
    elif len(args) == 2:
        sync_remote, url = args[0].lower() in ("true", "1", "yes"), args[1]
    else:
        raise SystemExit("usage: sync.py pr <network> [<sync-to-remote>] <github-pr-url>")
    m = PR_URL_RE.match(url)
    if not m:
        raise SystemExit(f"not a github PR URL: {url}")
    owner, repo, num = m.group(1), m.group(2), int(m.group(3))
    section = REPO_SECTIONS.get((owner, repo))
    if not section:
        raise SystemExit(
            f"no section mapped for {owner}/{repo}; add it to REPO_SECTIONS"
        )

    pr = github_pr(owner, repo, num)
    canonical_url = f"https://github.com/{owner}/{repo}/pull/{num}"
    new_line = (
        f"- [PR-{num} - {pr['title']}]({canonical_url}) {status_from_pr(pr)}\n"
    )

    path = local_path(network)
    with open(path) as f:
        lines = f.readlines()

    heading = f"**{section}**"
    section_start = next(
        (i for i, l in enumerate(lines) if l.strip() == heading), None
    )
    if section_start is None:
        raise SystemExit(f"section '{section}' not found in {network}.md")

    section_end = len(lines)
    for j in range(section_start + 1, len(lines)):
        s = lines[j].strip()
        if (s.startswith("**") and s.endswith("**")) or s.startswith("#"):
            section_end = j
            break

    insert_at = None
    last_pr_line = None
    for j in range(section_start + 1, section_end):
        pm = PR_LINE_RE.match(lines[j])
        if not pm:
            continue
        if (pm.group(1), pm.group(2)) == (owner, repo) and int(pm.group(3)) == num:
            print(f"PR-{num} already in {network}.md under '{section}'")
            return
        if int(pm.group(3)) > num:
            insert_at = j
            break
        last_pr_line = j

    if insert_at is None:
        insert_at = last_pr_line + 1 if last_pr_line is not None else section_start + 1

    lines.insert(insert_at, new_line)
    with open(path, "w") as f:
        f.writelines(lines)
    print(f"added PR-{num} to '{section}' in {network}.md")
    if sync_remote:
        push(network)


COMMANDS = {
    "from-remote": (pull, "<network>"),
    "to-remote": (push, "<network>"),
    "sync-prs": (sync_prs, "<network>"),
    "pr": (add_pr, "<network> [<sync-to-remote>] <github-pr-url>"),
}


def usage():
    print("usage:", file=sys.stderr)
    for name, (_, args) in COMMANDS.items():
        print(f"  sync.py {name} {args}", file=sys.stderr)
    sys.exit(1)


def main():
    argv = sys.argv[1:]
    if not argv or argv[0] not in COMMANDS:
        usage()
    fn, _ = COMMANDS[argv[0]]
    try:
        fn(*argv[1:])
    except TypeError:
        usage()


if __name__ == "__main__":
    main()
