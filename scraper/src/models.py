"""
Shared enums and result types for the PackingElf scraper.

ScraperStatus values are written verbatim into the stdout JSON, so they
must stay in sync with the C++ ScraperService parser.
"""
from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Optional


class ScraperStatus(str, Enum):
    SUCCESS = "SUCCESS"

    # Business outcomes
    ORDER_NOT_FOUND = "ORDER_NOT_FOUND"
    ORDER_CANCELED = "ORDER_CANCELED"
    STORE_CLOSED = "STORE_CLOSED"
    ALREADY_PICKED_UP = "ALREADY_PICKED_UP"

    # Login / navigation errors
    LOGIN_FAILED = "LOGIN_FAILED"
    MY_STORE_NOT_FOUND = "MY_STORE_NOT_FOUND"
    NETWORK_ERROR = "NETWORK_ERROR"

    # Scrape-step errors
    MULTIPLE_TABS = "MULTIPLE_TABS"
    POPUP_UNSOLVED = "POPUP_UNSOLVED"
    CHECKBOX_NOT_FOUND = "CHECKBOX_NOT_FOUND"
    PRINT_ERROR = "PRINT_ERROR"

    # Generic fallback
    ERROR = "ERROR"


@dataclass
class ScrapeResult:
    status: ScraperStatus
    buyer_name: Optional[str] = None
    order_date: Optional[str] = None
    total_amount: Optional[int] = None
    using_coupon: bool = False
    message: Optional[str] = None

    def to_json(self) -> dict:
        payload: dict = {
            "status": self.status.value,
            "using_coupon": self.using_coupon,
        }
        if self.buyer_name is not None:
            payload["buyer_name"] = self.buyer_name
        if self.order_date is not None:
            payload["order_date"] = self.order_date
        if self.total_amount is not None:
            payload["total_amount"] = self.total_amount
        if self.message:
            payload["message"] = self.message
        return payload
