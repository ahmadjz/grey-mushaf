#!/usr/bin/env python3
"""Codex usage: <threadId> [...] or --today / --since YYYY-MM-DD [--project cwd-substring]."""
import argparse, datetime, json, pathlib, sys

SESSIONS = pathlib.Path.home() / ".codex/sessions"
SOFT_AT, FULL_AT = 120_000, 160_000
KEYS = ("input_tokens", "cached_input_tokens", "output_tokens")


def rollout(thread_id):
    return next(SESSIONS.rglob(f"rollout-*{thread_id}.jsonl"), None)


def events(path):
    with path.open() as source:
        for line in source:
            try:
                yield json.loads(line)
            except ValueError:
                continue


def requests(path):
    """Yield counter advances once, including the baseline before any date filter."""
    previous = {}
    for event in events(path):
        payload = event.get("payload", {})
        info = payload.get("info") if payload.get("type") == "token_count" else None
        if not info or not info.get("total_token_usage"):
            continue
        current = info["total_token_usage"]
        delta = {key: max(0, current.get(key, 0) - previous.get(key, 0)) for key in KEYS}
        previous = current
        if any(delta.values()):
            yield event, delta, (info.get("last_token_usage") or {}).get("input_tokens")


def thread_state(path):
    """Return last request input, compaction, cumulative deltas, request count, model."""
    context, compacted, totals, calls, model = None, False, dict.fromkeys(KEYS, 0), 0, "?"
    for event in events(path):
        payload = event.get("payload", {})
        if event.get("type") == "turn_context":
            model = payload.get("model", model)
        elif event.get("type") == "compacted":
            compacted = True
    for _, delta, context in requests(path):
        calls += 1
        for key in KEYS:
            totals[key] += delta[key]
    return context, compacted, totals, calls, model


def status(thread_id):
    path = rollout(thread_id)
    if path is None:
        return "FULL"
    try:
        context, compacted, *_ = thread_state(path)
    except OSError:
        return "FULL"
    if context is None or compacted or context >= FULL_AT:
        return "FULL"
    return "SOFT" if context >= SOFT_AT else "OK"


def is_full(thread_id):
    return status(thread_id) == "FULL"


def columns(totals):
    inp, cached, out = (totals.get(key, 0) for key in KEYS)
    return f"input={inp}  cached={cached}  uncached={max(0, inp - cached)}  output={out}"


def show_thread(thread_id):
    path = rollout(thread_id)
    if path is None:
        print(f"{thread_id}  not found under {SESSIONS}  FULL")
        return
    context, compacted, totals, calls, model = thread_state(path)
    print(f"{thread_id}  {model}  calls={calls}  {columns(totals)}  context={context}"
          f"{' (compacted)' if compacted else ''}  {status(thread_id)}")


def summary(since=None, project=None, until=None):
    per_thread = {}
    for path in SESSIONS.rglob("rollout-*.jsonl"):
        meta = next((e["payload"] for e in events(path) if e.get("type") == "session_meta"), {})
        if project and project not in meta.get("cwd", ""):
            continue
        tid = meta.get("id", path.stem[-36:])
        for event, delta, _ in requests(path):
            stamp = event.get("timestamp")
            day = datetime.datetime.fromisoformat(stamp.replace("Z", "+00:00")).astimezone().date() if stamp else None
            if (since and (day is None or day < since)) or (until and (day is None or day > until)):
                continue
            row = per_thread.setdefault(tid, [dict.fromkeys(KEYS, 0), 0])
            for key in KEYS:
                row[0][key] += delta[key]
            row[1] += 1
    for tid, (totals, calls) in sorted(per_thread.items(), key=lambda item: -item[1][0]["input_tokens"]):
        print(f"{tid}  calls={calls}  {columns(totals)}")
    totals = {key: sum(row[0][key] for row in per_thread.values()) for key in KEYS}
    print(f"total  threads={len(per_thread)}  {columns(totals)}")


def today():
    summary(datetime.date.today(), until=datetime.date.today())


def main(args):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("threads", nargs="*")
    dates = parser.add_mutually_exclusive_group()
    dates.add_argument("--today", action="store_true")
    dates.add_argument("--since", type=datetime.date.fromisoformat)
    parser.add_argument("--project")
    options = parser.parse_args(args)
    if options.threads:
        if options.today or options.since or options.project:
            parser.error("summary filters cannot be combined with thread IDs")
        for tid in options.threads:
            show_thread(tid)
    elif options.today or options.since or options.project:
        summary(datetime.date.today() if options.today else options.since, options.project,
                datetime.date.today() if options.today else None)
    else:
        parser.error("pass thread IDs or a summary filter")


if __name__ == "__main__":
    main(sys.argv[1:])
