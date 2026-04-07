"""
__main__.py — CLI entry point for the PackingElf scraper.

Run as:
    python -m scraper <command> [options]

Commands
--------
scrape
    Scrapes a single order AND triggers the silent print.
    Output: one JSON line on stdout (C++ ScraperService reads this).

    # Automatic login (reads from encrypted account store):
    python -m scraper scrape --order PG02491384 --account "子午計畫"

    # Manual login (for testing / first run — you type credentials yourself):
    python -m scraper scrape --order PG02491384 --manual-login

    # Run headed (browser visible, default) vs headless:
    python -m scraper scrape --order PG02491384 --manual-login --headless

account
    Manage stored credentials (no browser needed).

    python -m scraper account list
    python -m scraper account add    --username "子午計畫"
    python -m scraper account update --username "子午計畫"
    python -m scraper account delete --username "子午計畫"

Notes
-----
• All progress/debug messages go to STDERR so they appear in the console
  without polluting the JSON stdout that the Qt app reads.
• The final result (one line of JSON) is always written to STDOUT.
• Exit code 0 = JSON written successfully (check "status" key for result).
• Exit code 1 = fatal error before any JSON could be written.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import sys

from .models  import ScraperStatus, ScrapeResult
from .account_store import AccountStore
from .scraper import MyAcgScraper


# ─── Stdout helpers ───────────────────────────────────────────────────────────

def emit(d: dict) -> None:
    """Write the final JSON result to stdout and flush."""
    print(json.dumps(d, ensure_ascii=False), flush=True)


def emit_error(status: ScraperStatus, message: str) -> None:
    emit({"status": status.value, "message": message})


# ─── scrape command ───────────────────────────────────────────────────────────

async def cmd_scrape(args: argparse.Namespace) -> None:
    scraper = MyAcgScraper(headless=getattr(args, "headless", False))
    try:
        await scraper.start()

        # ── Login ──────────────────────────────────────────────────
        if args.manual_login:
            err = await scraper.login_manual()
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

        # ── Navigate to My Store ───────────────────────────────────
        err = await scraper.navigate_to_store()
        if err:
            emit(err.to_json())
            return

        # ── Scrape the order ───────────────────────────────────────
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

    # ── scrape ────────────────────────────────────────────────────
    sp = sub.add_parser("scrape", help="Scrape and print one order")
    sp.add_argument("--order",  required=True,
                    help="Order number, e.g. PG02491384")
    sp.add_argument("--headless", action="store_true",
                    help="Run Chromium without a visible window")

    login_grp = sp.add_mutually_exclusive_group(required=True)
    login_grp.add_argument(
        "--account",
        help="Friendly account name (key in encrypted store), e.g. '子午計畫'",
    )
    login_grp.add_argument(
        "--manual-login", action="store_true",
        help="Open browser and wait for you to type credentials manually (testing mode)",
    )

    # ── account ───────────────────────────────────────────────────
    ap = sub.add_parser("account", help="Manage stored credentials")
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

    if args.command == "scrape":
        asyncio.run(cmd_scrape(args))
    elif args.command == "account":
        cmd_account(args)


if __name__ == "__main__":
    main()
