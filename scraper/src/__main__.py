"""
__main__.py — CLI entry point for the PackingElf scraper.

Run as:
    python -m scraper <command> [options]

Commands
--------
daemon (PRODUCTION — used by the Qt app)
    Launches the browser, logs in, navigates to My Store, then stays
    alive reading JSON commands from stdin and writing JSON events to stdout.

    python -m scraper daemon --account "子午計畫"
    python -m scraper daemon --manual-login

    Stdin commands (one JSON line each):
        {"cmd": "scrape",    "order_id": "uuid", "order_number": "PG02412345"}
        {"cmd": "calibrate"}
        {"cmd": "ping"}
        {"cmd": "quit"}

    Stdout events (one JSON line each):
        {"type": "ready"}
        {"type": "scrape_result", "order_id": "...", "status": "SUCCESS", ...}
        {"type": "calibrate_result", "ok": true, "url": "...", "message": "..."}
        {"type": "pong"}
        {"type": "error", "msg": "..."}

scrape (TESTING — one-shot, exits after printing)
    python -m scraper scrape --order PG02491384 --account "子午計畫"
    python -m scraper scrape --order PG02491384 --manual-login

account
    Manage stored credentials (no browser needed).
    python -m scraper account list
    python -m scraper account add    --username "子午計畫"
    python -m scraper account update --username "子午計畫"
    python -m scraper account delete --username "子午計畫"

Notes
-----
• All progress/debug messages go to STDERR (never pollute stdout JSON).
• stdout carries the structured JSON events that the Qt C++ app reads.
• Exit code 0 = clean shutdown.  Exit code 1 = fatal startup failure.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
from pathlib import Path
import sys

if __package__:
    from .models import ScraperStatus, ScrapeResult
    from .account_store import AccountStore
    from .scraper import MyAcgScraper
else:
    package_root = Path(__file__).resolve().parent.parent
    if str(package_root) not in sys.path:
        sys.path.insert(0, str(package_root))

    try:
        from src.models import ScraperStatus, ScrapeResult
        from src.account_store import AccountStore
        from src.scraper import MyAcgScraper
    except ImportError:
        source_root = Path(__file__).resolve().parent
        if str(source_root) not in sys.path:
            sys.path.insert(0, str(source_root))

        from models import ScraperStatus, ScrapeResult
        from account_store import AccountStore
        from scraper import MyAcgScraper


# ─── Stdout helpers ───────────────────────────────────────────────────────────

def emit(d: dict) -> None:
    """Write a JSON event to stdout (read by the Qt C++ ScraperService)."""
    print(json.dumps(d, ensure_ascii=False), flush=True)


def emit_error(status: ScraperStatus, message: str) -> None:
    emit({"status": status.value, "message": message})


# ─── Shared login helper ──────────────────────────────────────────────────────

async def _do_login(scraper: MyAcgScraper, args: argparse.Namespace) -> bool:
    """
    Perform login (auto or manual).
    Emits {"type":"error"} to stdout and returns False on failure.
    Returns True on success.
    """
    if args.manual_login:
        err = await scraper.login_manual()
    elif getattr(args, "direct_login", False):
        login_account = os.environ.get("PACKINGELF_MYACG_LOGIN", "").strip()
        password = os.environ.get("PACKINGELF_MYACG_PASSWORD", "")
        if not login_account or not password:
            emit({"type": "error", "msg": "Direct login credentials are missing."})
            return False
        err = await scraper.login(login_account, password)
    else:
        store    = AccountStore()
        acct_inf = store.get(args.account)
        if acct_inf is None:
            emit({"type": "error",
                  "msg": f"Account '{args.account}' not found. "
                         f"Run:  python -m scraper account add --username \"{args.account}\""})
            return False
        err = await scraper.login(acct_inf["account"], acct_inf["password"])

    if err:
        emit({"type": "error", "msg": f"Login failed: {err.message}"})
        return False
    return True


# ─── daemon command ───────────────────────────────────────────────────────────

async def cmd_daemon(args: argparse.Namespace) -> None:
    """
    Long-running mode: keep the browser alive and process commands from stdin.

    Lifecycle:
      1. Start browser, log in, navigate to My Store.
      2. Emit {"type": "ready"} to stdout.
      3. Loop: read JSON command from stdin → dispatch → emit result to stdout.
      4. Exit cleanly on {"cmd": "quit"} or stdin EOF.

    This is the mode used by the Qt desktop app (ScraperService::startBrowser()).
    """
    scraper = MyAcgScraper(headless=getattr(args, "headless", False))
    try:
        await scraper.start()

        if not await _do_login(scraper, args):
            return

        err = await scraper.navigate_to_store()
        if err:
            emit({"type": "error", "msg": f"Navigate to store failed: {err.message}"})
            return

        # Signal to C++ that we're ready for commands
        emit({"type": "ready"})

        # ── Command loop ─────────────────────────────────────────
        loop = asyncio.get_event_loop()
        print("[Scraper] Daemon ready. Waiting for commands on stdin…",
              file=sys.stderr, flush=True)

        while True:
            # Read one line from stdin in a thread (non-blocking on the event loop)
            raw = await loop.run_in_executor(None, sys.stdin.readline)
            if not raw:
                # stdin closed (C++ process exited or pipe broken) — quit cleanly
                print("[Scraper] stdin EOF — shutting down.", file=sys.stderr, flush=True)
                break

            raw = raw.strip()
            if not raw:
                continue

            try:
                cmd = json.loads(raw)
            except json.JSONDecodeError as e:
                emit({"type": "error", "msg": f"Bad JSON from host: {e} | raw: {raw}"})
                continue

            action = cmd.get("cmd", "")

            if action == "quit":
                print("[Scraper] Received quit command.", file=sys.stderr, flush=True)
                break

            elif action == "ping":
                emit({"type": "pong"})

            elif action == "scrape":
                order_id     = cmd.get("order_id", "")
                order_number = cmd.get("order_number", "")
                if not order_number:
                    emit({"type": "error", "msg": "scrape command missing order_number"})
                    continue
                try:
                    result = await scraper.scrape_order(order_number)
                    payload = result.to_json()
                    payload["type"]     = "scrape_result"
                    payload["order_id"] = order_id
                    emit(payload)
                except Exception as e:
                    import traceback
                    print(f"[Scraper] scrape ERROR: {traceback.format_exc()}",
                          file=sys.stderr, flush=True)
                    emit({"type": "scrape_result", "order_id": order_id,
                          "status": "ERROR", "message": str(e)})

            elif action == "calibrate":
                try:
                    result = await scraper.calibrate()
                    result["type"] = "calibrate_result"
                    emit(result)
                except Exception as e:
                    emit({"type": "calibrate_result", "ok": False,
                          "message": str(e)})

            else:
                emit({"type": "error", "msg": f"Unknown command: {action}"})

    except Exception as e:
        import traceback
        print(f"[Scraper] FATAL: {traceback.format_exc()}", file=sys.stderr, flush=True)
        emit({"type": "error", "msg": f"Unhandled exception: {e}"})

    finally:
        await scraper.close()


# ─── scrape command (one-shot, for testing) ───────────────────────────────────

async def cmd_scrape(args: argparse.Namespace) -> None:
    """One-shot mode: scrape a single order and exit. Used for CLI testing."""
    scraper = MyAcgScraper(headless=getattr(args, "headless", False))
    try:
        await scraper.start()

        if args.manual_login:
            err = await scraper.login_manual()
        elif getattr(args, "direct_login", False):
            login_account = os.environ.get("PACKINGELF_MYACG_LOGIN", "").strip()
            password = os.environ.get("PACKINGELF_MYACG_PASSWORD", "")
            if not login_account or not password:
                emit_error(ScraperStatus.ERROR, "Direct login credentials are missing.")
                return
            err = await scraper.login(login_account, password)
        else:
            store    = AccountStore()
            acct_inf = store.get(args.account)
            if acct_inf is None:
                emit_error(
                    ScraperStatus.ERROR,
                    f"Account '{args.account}' not found. "
                    f"Run:  python -m scraper account add --username \"{args.account}\"",
                )
                return
            err = await scraper.login(acct_inf["account"], acct_inf["password"])

        if err:
            emit(err.to_json())
            return

        err = await scraper.navigate_to_store()
        if err:
            emit(err.to_json())
            return

        result = await scraper.scrape_order(args.order)
        emit(result.to_json())

    except Exception as e:
        import traceback
        print(f"[Scraper] FATAL: {traceback.format_exc()}", file=sys.stderr, flush=True)
        emit_error(ScraperStatus.ERROR, f"Unhandled exception: {e}")

    finally:
        await scraper.close()


# ─── account command ──────────────────────────────────────────────────────────

def cmd_account(args: argparse.Namespace) -> None:
    store = AccountStore()

    if args.account_cmd == "list":
        names = store.all_names()
        print(f"Stored accounts ({len(names)}):", file=sys.stderr)
        for n in names:
            print(f"  • {n}", file=sys.stderr)
        emit({"status": "SUCCESS", "accounts": names})

    elif args.account_cmd == "add":
        print(f"\nAdding account: {args.username}", file=sys.stderr)
        acct = input("Enter myacg login (e-mail / account): ").strip()
        pwd  = input("Enter password: ").strip()
        if store.add(args.username, acct, pwd):
            emit({"status": "SUCCESS",
                  "message": f"Account '{args.username}' added."})
        else:
            emit({"status": "ERROR",
                  "message": f"Account '{args.username}' already exists. Use 'update'."})

    elif args.account_cmd == "update":
        print(f"\nUpdating account: {args.username}", file=sys.stderr)
        acct = input("Enter new myacg login: ").strip()
        pwd  = input("Enter new password: ").strip()
        if store.update(args.username, acct, pwd):
            emit({"status": "SUCCESS",
                  "message": f"Account '{args.username}' updated."})
        else:
            emit({"status": "ERROR",
                  "message": f"Account '{args.username}' not found."})

    elif args.account_cmd == "delete":
        if store.delete(args.username):
            emit({"status": "SUCCESS",
                  "message": f"Account '{args.username}' deleted."})
        else:
            emit({"status": "ERROR",
                  "message": f"Account '{args.username}' not found."})


# ─── Argument parser ──────────────────────────────────────────────────────────

def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="scraper",
        description="PackingElf web scraper for myacg.com.tw",
    )
    sub = p.add_subparsers(dest="command", required=True)

    # ── daemon (production) ───────────────────────────────────────
    dp = sub.add_parser("daemon", help="Long-running browser daemon (used by Qt app)")
    dp.add_argument("--headless", action="store_true",
                    help="Run Chromium without a visible window")
    dlogin = dp.add_mutually_exclusive_group(required=True)
    dlogin.add_argument("--account",
                        help="Friendly account name in encrypted store")
    dlogin.add_argument("--direct-login", action="store_true",
                        help="Read login/password from environment variables")
    dlogin.add_argument("--manual-login", action="store_true",
                        help="Wait for you to log in manually in the browser")
    dp.add_argument("--account-label",
                    help="Friendly label for direct login mode")

    # ── scrape (one-shot testing) ─────────────────────────────────
    sp = sub.add_parser("scrape", help="One-shot: scrape and print one order then exit")
    sp.add_argument("--order",   required=True, help="Order number, e.g. PG02491384")
    sp.add_argument("--headless", action="store_true")
    slogin = sp.add_mutually_exclusive_group(required=True)
    slogin.add_argument("--account")
    slogin.add_argument("--direct-login", action="store_true")
    slogin.add_argument("--manual-login", action="store_true")
    sp.add_argument("--account-label")

    # ── account ───────────────────────────────────────────────────
    ap   = sub.add_parser("account", help="Manage stored credentials")
    asub = ap.add_subparsers(dest="account_cmd", required=True)

    asub.add_parser("list", help="List all stored account names")

    add_p = asub.add_parser("add",    help="Add a new account (prompts for credentials)")
    add_p.add_argument("--username", required=True, help="Friendly name, e.g. '子午計畫'")

    upd_p = asub.add_parser("update", help="Update an existing account's credentials")
    upd_p.add_argument("--username", required=True)

    del_p = asub.add_parser("delete", help="Delete a stored account")
    del_p.add_argument("--username", required=True)

    return p


# ─── Entry point ──────────────────────────────────────────────────────────────

def main() -> None:
    parser = build_parser()
    args   = parser.parse_args()

    if args.command == "daemon":
        asyncio.run(cmd_daemon(args))
    elif args.command == "scrape":
        asyncio.run(cmd_scrape(args))
    elif args.command == "account":
        cmd_account(args)


if __name__ == "__main__":
    main()
