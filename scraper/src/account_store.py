"""
account_store.py — Encrypted credential storage for myacg.com.tw accounts.

Credentials are stored in:
    %APPDATA%\\Meridian\\PackingElf\\accounts.enc

The file is AES-128 encrypted via cryptography.fernet.
The key is derived from a fixed app secret + the machine's COMPUTERNAME,
so the file cannot be trivially copied to another machine and decrypted.

CLI quick-start:
    python -m scraper account add --username "子午計畫"
    python -m scraper account list
"""
from __future__ import annotations

import base64
import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Optional

from cryptography.fernet import Fernet, InvalidToken


# ─── Key derivation ───────────────────────────────────────────────────────────

_APP_SECRET = b"PackingElf_MyAcg_Scraper_v1"
_SALT       = b"packingelf_account_store"


def _derive_key() -> bytes:
    """
    Derives a 32-byte key from the app secret + machine hostname using PBKDF2.
    The hostname ties the file to this machine (basic obfuscation, not HSM-grade).
    """
    hostname = os.environ.get("COMPUTERNAME", "unknown").encode("utf-8", errors="replace")
    raw = hashlib.pbkdf2_hmac(
        "sha256",
        _APP_SECRET + hostname,
        _SALT,
        iterations=100_000,
        dklen=32,
    )
    return base64.urlsafe_b64encode(raw)


# ─── File path ────────────────────────────────────────────────────────────────

def _store_path() -> Path:
    """Returns the path to the encrypted accounts file, creating dirs as needed."""
    app_data = os.environ.get("APPDATA", str(Path.home()))
    p = Path(app_data) / "Meridian" / "PackingElf" / "accounts.enc"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


# ─── AccountStore class ───────────────────────────────────────────────────────

class AccountStore:
    """
    Simple encrypted key-value store for myacg.com.tw credentials.

    Each entry is keyed by a friendly ``username`` (e.g. "子午計畫") and
    stored as ``{"account": "...", "password": "..."}``.
    """

    def __init__(self) -> None:
        self._fernet   = Fernet(_derive_key())
        self._accounts: dict[str, dict] = {}
        self._load()

    # ── Persistence ──────────────────────────────────────────────

    def _load(self) -> None:
        path = _store_path()
        if not path.exists():
            self._accounts = {}
            return
        try:
            raw       = path.read_bytes()
            decrypted = self._fernet.decrypt(raw)
            self._accounts = json.loads(decrypted.decode("utf-8"))
            print(f"[AccountStore] Loaded {len(self._accounts)} account(s).", file=sys.stderr)
        except InvalidToken:
            print("[AccountStore] ERROR: decryption failed — wrong key or corrupted file.", file=sys.stderr)
            self._accounts = {}
        except Exception as e:
            print(f"[AccountStore] ERROR loading accounts: {e}", file=sys.stderr)
            self._accounts = {}

    def _save(self) -> None:
        path = _store_path()
        raw       = json.dumps(self._accounts, ensure_ascii=False).encode("utf-8")
        encrypted = self._fernet.encrypt(raw)
        path.write_bytes(encrypted)
        print(f"[AccountStore] Saved {len(self._accounts)} account(s) → {path}", file=sys.stderr)

    # ── Public API ───────────────────────────────────────────────

    def get(self, username: str) -> Optional[dict]:
        """Return ``{"account": ..., "password": ...}`` or None."""
        return self._accounts.get(username)

    def all_names(self) -> list[str]:
        """Return all stored usernames."""
        return list(self._accounts.keys())

    def add(self, username: str, account: str, password: str) -> bool:
        """Add a new account. Returns False if username already exists."""
        if username in self._accounts:
            return False
        self._accounts[username] = {"account": account, "password": password}
        self._save()
        return True

    def update(self, username: str, account: str, password: str) -> bool:
        """Update existing credentials. Returns False if not found."""
        if username not in self._accounts:
            return False
        self._accounts[username] = {"account": account, "password": password}
        self._save()
        return True

    def delete(self, username: str) -> bool:
        """Delete an account. Returns False if not found."""
        if username not in self._accounts:
            return False
        del self._accounts[username]
        self._save()
        return True
