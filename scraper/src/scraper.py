"""
scraper.py — Core browser automation for myacg.com.tw.

Wraps Playwright Chromium to reproduce the behaviour of the old
myacg_manager.py (Selenium), with these improvements:
  • Playwright has built-in auto-waiting — no explicit WebDriverWait needed.
  • Dialog (alert/confirm) events are handled with a registered listener,
    so they never block execution.
  • Every step is logged to stderr so you can watch progress in the console.
  • All exceptions are caught at the individual step level; the calling
    code (index.py / __main__.py) catches anything that slips through.

Manual-login mode (--manual-login flag):
  The browser opens headed, navigates to the login page, then waits up to
  90 seconds for the user to type credentials and click Submit themselves.
  Once the URL moves away from login.php the scraper proceeds automatically.
"""
from __future__ import annotations

import asyncio
import sys
from typing import Optional

from playwright.async_api import (
    async_playwright,
    Browser,
    BrowserContext,
    Page,
    TimeoutError as PlaywrightTimeout,
)

from .models import ScraperStatus, ScrapeResult

# ─── Constants ────────────────────────────────────────────────────────────────

LOGIN_URL = (
    "https://www.myacg.com.tw/login.php"
    "?done=http%3A%2F%2Fwww.myacg.com.tw%2Findex.php"
)

TIMEOUT_SHORT  =  8_000   # ms — find elements that should already be on page
TIMEOUT_NORMAL = 15_000   # ms — standard wait
TIMEOUT_LONG   = 30_000   # ms — page navigation / slow loads
TIMEOUT_MANUAL = 90_000   # ms — user manually types credentials


# ─── Helpers ──────────────────────────────────────────────────────────────────

def log(msg: str) -> None:
    """Print a timestamped debug line to stderr (never pollutes stdout JSON)."""
    print(f"[Scraper] {msg}", file=sys.stderr, flush=True)


# ─── Main class ───────────────────────────────────────────────────────────────

class MyAcgScraper:
    """
    Controls a Chromium browser to log in and scrape order data from
    myacg.com.tw.  All public ``async`` methods return a ``ScrapeResult``
    on failure or ``None`` on success (caller checks and short-circuits).
    """

    def __init__(self, headless: bool = False) -> None:
        self._headless = headless
        self._pw       = None
        self._browser: Optional[Browser]        = None
        self._context: Optional[BrowserContext] = None
        self._page:    Optional[Page]           = None
        # Stores the last dialog message (set by the event handler)
        self._last_dialog: Optional[str] = None

    # ── Lifecycle ─────────────────────────────────────────────────

    async def start(self) -> None:
        """Launch Playwright + Chromium. Call once before any other method."""
        log("Starting Playwright/Chromium…")
        self._pw      = await async_playwright().start()
        self._browser = await self._pw.chromium.launch(
            headless=self._headless,
            args=[
                "--kiosk-printing",          # Silent print (no print dialog)
                "--enable-print-browser",
                # Hide automation fingerprint so the site doesn't detect us
                "--disable-blink-features=AutomationControlled",
            ],
        )
        self._context = await self._browser.new_context(
            viewport={"width": 1280, "height": 900},
        )
        self._page = await self._context.new_page()
        self._page.set_default_timeout(TIMEOUT_NORMAL)

        # Register dialog auto-acceptor BEFORE any navigation.
        # The old code used driver.switch_to.alert; Playwright uses events.
        # If the site shows "wrong credentials" or "store closed" alerts,
        # _on_dialog fires, captures the text, and auto-accepts.
        self._page.on("dialog", self._on_dialog)

        log("Browser launched successfully.")

    async def close(self) -> None:
        """Close the browser and stop Playwright. Safe to call multiple times."""
        log("Closing browser…")
        try:
            if self._context: await self._context.close()
            if self._browser: await self._browser.close()
            if self._pw:      await self._pw.stop()
        except Exception as e:
            log(f"  (ignored close error: {e})")
        log("Done.")

    def _on_dialog(self, dialog) -> None:
        """
        Playwright dialog event. Captures the message and auto-accepts.
        The old code had manual switch_to.alert — this is cleaner.
        """
        log(f"  ⚠ Browser dialog: \"{dialog.message}\"")
        self._last_dialog = dialog.message
        asyncio.ensure_future(dialog.accept())

    # ── Login ─────────────────────────────────────────────────────

    async def login(self, account: str, password: str) -> Optional[ScrapeResult]:
        """
        Auto-fills login form with stored credentials and submits.
        Returns None on success, ScrapeResult on failure.
        """
        log(f"Navigating to login page…")
        try:
            await self._page.goto(LOGIN_URL, timeout=TIMEOUT_LONG,
                                  wait_until="domcontentloaded")
        except Exception as e:
            return ScrapeResult(ScraperStatus.NETWORK_ERROR,
                                message=f"Cannot reach login page: {e}")

        log("Filling account field…")
        try:
            await self._page.wait_for_selector('[name="account"]',
                                              timeout=TIMEOUT_NORMAL)
            await self._page.fill('[name="account"]', account)
            log(f"  Account: {account}")
        except Exception as e:
            return ScrapeResult(ScraperStatus.LOGIN_FAILED,
                                message=f"Account field not found: {e}")

        log("Filling password field…")
        try:
            await self._page.fill('[name="password"]', password)
            log("  Password: ●●●●●●")
        except Exception as e:
            return ScrapeResult(ScraperStatus.LOGIN_FAILED,
                                message=f"Password field not found: {e}")

        log("Clicking login button…")
        try:
            btn = self._page.locator(
                'xpath=//*[@id="form1"]/div/div/div[2]/div[5]/div[1]/a'
            )
            await btn.wait_for(state="visible", timeout=TIMEOUT_NORMAL)
            await btn.click()
            log("  Login button clicked.")
        except Exception as e:
            return ScrapeResult(ScraperStatus.LOGIN_FAILED,
                                message=f"Login button not found: {e}")

        # Brief pause so the browser can show an error alert if credentials
        # are wrong before we proceed.  The dialog handler captures it.
        await asyncio.sleep(2.5)

        if self._last_dialog:
            log(f"  Login dialog detected; treating as wrong credentials.")
            return ScrapeResult(ScraperStatus.LOGIN_FAILED,
                                message=f"Site alert: {self._last_dialog}")

        log("Credentials submitted — waiting for post-login page…")
        return None   # success

    async def login_manual(self) -> Optional[ScrapeResult]:
        """
        Navigate to login page and wait for the user to enter credentials
        manually in the browser window.  Automatically resumes once the URL
        leaves login.php (i.e., the user successfully logged in).

        Use --manual-login for development/testing without stored credentials.
        """
        log("=== MANUAL LOGIN MODE ===")
        log(f"Navigating to: {LOGIN_URL}")
        try:
            await self._page.goto(LOGIN_URL, timeout=TIMEOUT_LONG,
                                  wait_until="domcontentloaded")
        except Exception as e:
            return ScrapeResult(ScraperStatus.NETWORK_ERROR,
                                message=f"Cannot reach login page: {e}")

        log("─────────────────────────────────────────────")
        log(">>> Please type your credentials in the browser window.")
        log(">>> Press the LOGIN button yourself when ready.")
        log(">>> The scraper will resume automatically once it detects")
        log(">>> that you have successfully logged in.")
        log(">>> You have 90 seconds.")
        log("─────────────────────────────────────────────")

        try:
            # Wait for URL to change away from login.php
            await self._page.wait_for_url(
                lambda url: "login.php" not in url,
                timeout=TIMEOUT_MANUAL,
            )
            log("Login detected!  Resuming automation…")
            return None   # success
        except PlaywrightTimeout:
            return ScrapeResult(
                ScraperStatus.LOGIN_FAILED,
                message="Manual login timed out after 90 seconds.",
            )

    # ── Navigation ────────────────────────────────────────────────

    async def navigate_to_store(self) -> Optional[ScrapeResult]:
        """
        Click '我的賣場' (My Store) after login.
        The old code located '//*[@id="topbar"]/div/ul/li[1]/a'.
        """
        log("Navigating to 我的賣場 (My Store)…")
        try:
            el = self._page.locator(
                'xpath=//*[@id="topbar"]/div/ul/li[1]/a'
            )
            await el.wait_for(state="visible", timeout=TIMEOUT_LONG)
            await el.click()
            log("  My Store clicked.")
            # Wait a moment for the store page to begin loading
            await self._page.wait_for_load_state("domcontentloaded",
                                                  timeout=TIMEOUT_LONG)
            return None
        except Exception as e:
            return ScrapeResult(ScraperStatus.MY_STORE_NOT_FOUND,
                                message=f"My Store button not found: {e}")

    # ── Order scraping ────────────────────────────────────────────

    async def scrape_order(self, order_number: str) -> ScrapeResult:
        """
        Search for ``order_number``, extract buyer info, tick checkbox,
        trigger silent print.  Mirrors the old printer() function.

        Selectors verified against live myacg.com.tw seller dashboard HTML.
        """
        log(f"══════ Scraping order: {order_number} ══════")

        # ── 0. Sanity: close any stray extra tabs ─────────────────
        pages = self._context.pages
        if len(pages) > 1:
            log(f"  WARNING: {len(pages)} tabs open — closing extras…")
            for p in pages[1:]:
                try: await p.close()
                except: pass

        # ── 1. Fill search bar and submit ─────────────────────────
        # Real element: <input type="text" id="o_num" name="o_num" ...>
        log("  Step 1/9 — Searching for order…")
        try:
            sb = self._page.locator('#o_num')
            await sb.wait_for(state="visible", timeout=TIMEOUT_NORMAL)
            await sb.fill(order_number)
            log(f"    Search bar filled: {order_number}")
        except Exception as e:
            log("    Search bar not found; page may have changed.")
            if self._last_dialog:
                return ScrapeResult(ScraperStatus.STORE_CLOSED,
                                    message=f"Dialog was present: {self._last_dialog}")
            return ScrapeResult(ScraperStatus.POPUP_UNSOLVED, message=str(e))

        # Real element: <a href="javascript:void(0);" class="btn_base_yellow"
        #                  onclick="query();">訂單搜尋</a>
        # CRITICAL: onclick="query()" is pure JS — no navigation occurs.
        # Using .click() makes Playwright wait for navigation → always times out.
        # Fix: evaluate JS click directly to bypass navigation wait.
        # NOTE: .btn_base_yellow matches TWO elements (also 匯出 export button).
        #       Use the onclick attribute which is unique to the search button.
        try:
            search_btn = self._page.locator('a[onclick="query();"]')
            await search_btn.wait_for(state="visible", timeout=TIMEOUT_NORMAL)
            await search_btn.evaluate("el => el.click()")
            log("    Search button clicked (JS evaluate — no nav wait).")
        except Exception as e:
            return ScrapeResult(ScraperStatus.ERROR,
                                message=f"Search button not found: {e}")

        # Wait for results to appear — either the order table or no-data message
        try:
            await self._page.wait_for_selector(
                '#wrap .orderTable, .search_no_data2',
                timeout=TIMEOUT_NORMAL
            )
        except Exception as e:
            log(f"    Warning — results selector timed out: {e}")

        # ── 2. Check: order exists? ───────────────────────────────
        # Real element: <div class="search_no_data2"> ... 您沒有訂單 ...
        log("  Step 2/9 — Checking if order exists…")
        try:
            no_data = self._page.locator('.search_no_data2')
            if await no_data.is_visible(timeout=TIMEOUT_SHORT):
                log("    → ORDER_NOT_FOUND (.search_no_data2 present)")
                return ScrapeResult(ScraperStatus.ORDER_NOT_FOUND)
        except: pass

        # ── 3. Check: canceled? ───────────────────────────────────
        # Real element: <span class="t_red">取消原因</span>
        log("  Step 3/9 — Checking if order is canceled…")
        try:
            canceled = self._page.locator(
                'xpath=//span[@class="t_red" and contains(normalize-space(text()),"取消原因")]'
            )
            if await canceled.is_visible(timeout=TIMEOUT_SHORT):
                log("    → ORDER_CANCELED")
                return ScrapeResult(ScraperStatus.ORDER_CANCELED)
        except: pass

        # ── 4. Check: store/order closed? ────────────────────────
        # Real element: <span class="t_red" data-state="close">關轉中，等待重選門市</span>
        log("  Step 4/9 — Checking if order is closed…")
        try:
            closed = self._page.locator('[data-state="close"]')
            if await closed.is_visible(timeout=TIMEOUT_SHORT):
                log("    → STORE_CLOSED (data-state=close)")
                return ScrapeResult(ScraperStatus.STORE_CLOSED)
        except: pass

        # ── 5. Coupon detection ───────────────────────────────────
        # Old code: td[6]/p element — keeping same XPATH as it targets a specific cell
        log("  Step 5/9 — Checking coupon usage…")
        using_coupon = False
        try:
            coupon_el = self._page.locator(
                'xpath=//*[@id="wrap"]/div[2]/div[2]/div[1]/table/tbody/tr[1]/td[6]/p'
            )
            if await coupon_el.is_visible(timeout=TIMEOUT_SHORT):
                using_coupon = True
                log("    Coupon: YES")
            else:
                log("    Coupon: NO")
        except:
            log("    Coupon: could not determine (defaulting NO)")

        # ── 6. Extract order date ─────────────────────────────────
        # Real element: <div class="order_process_text_orange">下單完成 <br> 2026-03-30 11:08:21</div>
        # The FIRST orange block = order creation date. Text split by \n → last line is the date.
        log("  Step 6/9 — Extracting order date…")
        order_date: Optional[str] = None
        try:
            date_el  = self._page.locator(".order_process_text_orange").first
            full_txt = await date_el.inner_text(timeout=TIMEOUT_NORMAL)
            order_date = full_txt.split("\n")[-1].strip()
            log(f"    Order date: {order_date}")
        except Exception as e:
            log(f"    Warning — order date not found: {e}")

        # ── 7. Extract buyer name ─────────────────────────────────
        # Real element:
        #   <span style="max-width:100px;...">買家: phiip4607</span>
        # XPath: find first span whose text contains '買家:'
        log("  Step 7/9 — Extracting buyer name…")
        buyer_name: Optional[str] = None
        try:
            buyer_el = self._page.locator(
                'xpath=//span[contains(text(),"買家:")]'
            ).first
            buyer_text = await buyer_el.inner_text(timeout=TIMEOUT_SHORT)
            buyer_name = buyer_text.replace("買家:", "").strip()
            log(f"    Buyer name: {buyer_name}")
        except Exception as e:
            log(f"    Warning — buyer name not found: {e}")

        # ── 8. Click order checkbox ───────────────────────────────
        # Real element: magic-checkbox pattern
        #   <input class="magic-checkbox" type="checkbox" id="oid_check_2784862" ...>
        #   <label for="oid_check_2784862"></label>
        #
        # BOTH the <input> and <label> are CSS-hidden (that's the magic-checkbox trick).
        # Playwright's wait_for(state="visible") always fails on both.
        # Solution: bypass Playwright locators entirely and call
        # document.getElementById().click() directly from page JS — identical to
        # what the old Selenium execute_script("arguments[0].click()", el) did.
        numeric_id = order_number[3:]
        log(f"  Step 8/9 — Clicking checkbox via JS (oid_check_{numeric_id})…")
        try:
            clicked = await self._page.evaluate(f"""
                (() => {{
                    const el = document.getElementById('oid_check_{numeric_id}');
                    if (!el) return false;
                    el.click();
                    return el.checked;
                }})()
            """)
            if clicked is False:
                log("    WARNING: checkbox element not found in DOM via JS.")
                return ScrapeResult(
                    ScraperStatus.CHECKBOX_NOT_FOUND,
                    buyer_name=buyer_name, order_date=order_date,
                    using_coupon=using_coupon,
                    message=f"document.getElementById('oid_check_{numeric_id}') returned null",
                )
            log(f"    Checkbox clicked via JS. Checked state: {clicked}")
        except Exception as e:
            return ScrapeResult(
                ScraperStatus.CHECKBOX_NOT_FOUND,
                buyer_name=buyer_name, order_date=order_date,
                using_coupon=using_coupon,
                message=f"JS click on oid_check_{numeric_id} failed: {e}",
            )


        # ── 9. Click print button and handle new tab ──────────────
        # Element: <a id="PrintBatch_2" class="select_box_base2 bg_blue_light"
        #             href="javascript:void(0);" onclick="..."
        #          >批量列印超商出貨單</a>
        #
        # Clicking opens a NEW TAB with the print preview.
        # Use context.expect_page() — Playwright's proper API for awaiting a new tab.
        # This is reliable; asyncio.sleep + checking context.pages is not.
        #
        # For printing: window.print() works AS LONG AS the browser's default
        # printer is set to a physical printer (not "Save as PDF").
        # This is the same approach as the old Selenium execute_script('window.print()').
        log("  Step 9/9 — Clicking BatchPrint button (PrintBatch_2)…")
        try:
            # Trigger click AND wait for the new tab simultaneously
            async with self._context.expect_page(timeout=TIMEOUT_LONG) as new_page_info:
                await self._page.evaluate(
                    "document.getElementById('PrintBatch_2').click()"
                )
            print_page = await new_page_info.value
            log("  Print tab opened — switched to it.")
        except Exception as e:
            # A dialog may have fired instead of a new tab (e.g. store closed warning)
            if self._last_dialog:
                log(f"  Dialog appeared instead of print tab: '{self._last_dialog}'")
                return ScrapeResult(
                    ScraperStatus.STORE_CLOSED,
                    buyer_name=buyer_name, order_date=order_date,
                    using_coupon=using_coupon,
                    message=f"Dialog intercepted print: {self._last_dialog}",
                )
            return ScrapeResult(
                ScraperStatus.PRINT_ERROR,
                buyer_name=buyer_name, order_date=order_date,
                using_coupon=using_coupon,
                message=f"Print tab did not open: {e}",
            )

        # Wait for the print page DOM to be ready before calling window.print()
        try:
            await print_page.wait_for_load_state("domcontentloaded", timeout=TIMEOUT_LONG)
            log("  Print page DOM loaded.")
        except Exception as e:
            log(f"  Warning — print page load slow: {e}")

        # Trigger print dialog — same method as old Selenium execute_script("window.print()")
        # Requires browser default printer to be a physical printer (not PDF).
        try:
            await print_page.evaluate("() => window.print()")
            log("  window.print() called.")
        except Exception as e:
            log(f"  Warning — window.print() error (non-fatal): {e}")

        # Close print tab and return focus to main seller dashboard tab
        try:
            await print_page.close()
            await self._page.bring_to_front()
            log("  Print tab closed — back on main seller tab.")
        except Exception as e:
            log(f"  Warning — could not close print tab: {e}")

        log(f"══════ Order {order_number} complete ══════")
        return ScrapeResult(
            status=ScraperStatus.SUCCESS,
            buyer_name=buyer_name,
            order_date=order_date,
            using_coupon=using_coupon,
        )
