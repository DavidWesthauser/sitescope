#!/usr/bin/env python3
"""Keep docs/tickets consistent: one folder per status and a generated index.

Each ticket's header line (`- Status: todo · ...`) is the source of truth. The script moves every
ticket into `todo/`, `in-progress/` or `done/`, rewrites links that point at tickets, and regenerates
the table between the index markers in docs/tickets/README.md.

Usage: python3 scripts/tickets.py          apply changes
       python3 scripts/tickets.py --check  exit 1 if anything is out of date (changes nothing)
       python3 scripts/tickets.py --lint   report tickets that do not follow the template
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TICKETS = ROOT / "docs" / "tickets"
INDEX = TICKETS / "README.md"
FOLDERS = {"todo": "todo", "blocked": "todo", "in-progress": "in-progress", "done": "done"}
SECTIONS = [("in-progress", "In progress"), ("todo", "To do"), ("done", "Done")]
START, END = "<!-- index:start -->", "<!-- index:end -->"
TICKET_LINK = re.compile(r"\]\(((?:[\w./-]*/)?(T-\d+[a-z]?-[\w.-]+\.md))\)")


def field(header: str, name: str) -> str:
    match = re.search(rf"{name}:\s*([^·\n]*)", header)
    return match.group(1).strip() if match else ""


def parse(path: Path) -> dict:
    text = path.read_text()
    title = re.search(r"^# (T-\d+[a-z]?) (.+)$", text, re.M)
    header = re.search(r"^- Status:.*$", text, re.M)
    requirements = re.search(r"^- Requirements:\s*(.+)$", text, re.M)
    if not (title and header):
        sys.exit(f"{path.relative_to(ROOT)}: needs '# T-XXX Title' and a '- Status: ...' line")
    status = field(header.group(0), "Status")
    if status not in FOLDERS:
        sys.exit(f"{path.relative_to(ROOT)}: unknown status '{status}' (use {', '.join(FOLDERS)})")
    return {
        "id": title.group(1), "title": title.group(2).strip(), "path": path, "status": status,
        "priority": field(header.group(0), "Priority"), "estimate": field(header.group(0), "Estimate"),
        "owner": field(header.group(0), "Owner"), "depends": field(header.group(0), "Depends on"),
        "requirements": requirements.group(1).strip() if requirements else "",
    }


def sort_key(ticket_id: str):
    number, letter = re.match(r"T-(\d+)([a-z]?)", ticket_id).groups()
    return int(number), letter


def relink(text: str, source_dir: Path, targets: dict) -> str:
    """Point every link to a ticket file at that ticket's new location, relative to `source_dir`."""
    def replace(match):
        name = match.group(2)
        if name not in targets:
            return match.group(0)
        return "](" + os.path.relpath(targets[name], source_dir) + ")"
    return TICKET_LINK.sub(replace, text)


def relink_relative(text: str, old_dir: Path, new_dir: Path) -> str:
    """Keep non-ticket relative links (e.g. ../REQUIREMENTS.md) valid after a file moves."""
    def replace(match):
        target = match.group(1)
        if re.match(r"^[a-z]+:|^#|^/", target) or TICKET_LINK.match("](" + target + ")"):
            return match.group(0)
        path, _, anchor = target.partition("#")
        resolved = (old_dir / path).resolve()
        new = os.path.relpath(resolved, new_dir)
        return "](" + new + ("#" + anchor if anchor else "") + ")"
    return re.sub(r"\]\(([^)\s]+)\)", replace, text)


def index_table(tickets: list) -> str:
    epics = {t["id"] for t in tickets for s in tickets if re.fullmatch(t["id"] + "[a-z]", s["id"])}
    lines = []
    for status, heading in SECTIONS:
        rows = [t for t in tickets if FOLDERS[t["status"]] == status]
        lines.append(f"### {heading} ({len(rows)})\n")
        if not rows:
            lines.append("None.\n")
            continue
        lines.append("| ID | Title | Prio | Est. | Req. | Depends | Owner |")
        lines.append("|---|---|---|---:|---|---|---|")
        for t in sorted(rows, key=lambda t: sort_key(t["id"])):
            link = os.path.relpath(t["target"], TICKETS)
            label = f"↳ [{t['id']}]({link})" if re.search(r"[a-z]$", t["id"]) else f"[{t['id']}]({link})"
            title = t["title"] + (" *(epic)*" if t["id"] in epics else "")
            if t["status"] == "blocked":
                title += " *(blocked)*"
            owner = "" if t["owner"] in ("", "—") else t["owner"]
            lines.append(f"| {label} | {title} | {t['priority']} | {t['estimate']} | {t['requirements']} "
                         f"| {t['depends']} | {owner} |")
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


HEADER = re.compile(
    r"^- Status: (todo|blocked|in-progress|done) · Priority: P[0-3] · Estimate: [^·]+ · Owner: [^·]+ · Depends on: .+$")
SECTIONS_REQUIRED = ["## Goal", "## Tasks", "## Acceptance criteria"]
SECTIONS_EPIC = ["## Goal", "## Sub-tickets", "## Acceptance criteria"]


def lint(path: Path) -> list:
    """Return format problems: every ticket follows the template in docs/tickets/README.md."""
    lines = path.read_text().splitlines()
    problems = []
    if not re.fullmatch(r"# T-\d+[a-z]? \S.*", lines[0] if lines else ""):
        problems.append("line 1 must be '# T-XXX Title'")
    if len(lines) < 4 or lines[1] != "" or not HEADER.match(lines[2]):
        problems.append("line 3 must be '- Status: … · Priority: P0-3 · Estimate: … · Owner: … · Depends on: …'")
    if len(lines) < 4 or not lines[3].startswith("- Requirements: "):
        problems.append("line 4 must be '- Requirements: …'")
    headings = [line for line in lines if line.startswith("## ")]
    expected = SECTIONS_EPIC if "## Sub-tickets" in headings else SECTIONS_REQUIRED
    if [h for h in headings if h != "## Notes"] != expected or (headings and "## Notes" in headings[:-1]):
        problems.append(f"sections must be {' / '.join(expected)} (optional '## Notes' last); found {headings}")
    for i, line in enumerate(lines):
        if line.startswith("#") and i + 1 < len(lines) and lines[i + 1] != "":
            problems.append(f"line {i + 1}: blank line needed after heading")
    if not any(line.startswith("- [") for line in lines):
        problems.append("needs checkbox items")
    return problems


def main() -> int:
    if "--lint" in sys.argv:
        failed = 0
        for path in sorted(TICKETS.rglob("T-*.md")):
            for problem in lint(path):
                print(f"{path.relative_to(ROOT)}: {problem}")
                failed = 1
        return failed
    check = "--check" in sys.argv
    tickets = [parse(p) for p in sorted(TICKETS.rglob("T-*.md"))]
    ids = [t["id"] for t in tickets]
    duplicates = {i for i in ids if ids.count(i) > 1}
    if duplicates:
        sys.exit("duplicate ticket IDs: " + ", ".join(sorted(duplicates)))
    for t in tickets:
        t["target"] = TICKETS / FOLDERS[t["status"]] / t["path"].name
    targets = {t["path"].name: t["target"] for t in tickets}

    pending = []  # (path to write, new text, path to remove or None)
    for t in tickets:
        old = t["path"].read_text()
        new = relink(relink_relative(old, t["path"].parent, t["target"].parent), t["target"].parent, targets)
        if t["target"] != t["path"]:
            pending.append((t["target"], new, t["path"]))
        elif new != old:
            pending.append((t["path"], new, None))

    # Other Markdown files that link to tickets (status page, docs index, agent instructions).
    others = [p for p in ROOT.glob("*.md")] + [p for p in (ROOT / "docs").rglob("*.md") if TICKETS not in p.parents]
    for path in others:
        old = path.read_text()
        new = relink(old, path.parent, targets)
        if path == INDEX:
            continue
        if new != old:
            pending.append((path, new, None))

    index_old = INDEX.read_text()
    if START not in index_old or END not in index_old:
        sys.exit(f"{INDEX.relative_to(ROOT)} needs the markers {START} and {END}")
    head, rest = index_old.split(START, 1)
    _, tail = rest.split(END, 1)
    index_new = relink(head, INDEX.parent, targets) + START + "\n\n" + index_table(tickets) + "\n" + END
    index_new += relink(tail, INDEX.parent, targets)
    if index_new != index_old:
        pending.append((INDEX, index_new, None))

    if check:
        for path, _, moved in pending:
            print("out of date:", (moved or path).relative_to(ROOT))
        return 1 if pending else 0
    for path, text, moved in pending:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if moved:
            moved.unlink()
            print("moved", moved.relative_to(TICKETS), "->", path.relative_to(TICKETS))
    print(f"{len(tickets)} tickets, index up to date")
    return 0


if __name__ == "__main__":
    sys.exit(main())
