# app/core/utils/otp_logger.py
# ============================================================
# 📢 OTP TERMINAL LOGGER - CORRECT STATUS DISPLAY
# ============================================================
# ✅ Shows REAL status of each channel (no false success)
# ✅ Distinguishes: SENT / FAILED / BYPASSED / SKIPPED
# ✅ Accepts skipped_channels parameter
# ============================================================

import logging
from datetime import datetime
from typing import Optional, Dict

logger = logging.getLogger(__name__)


class OTPLogger:
    """Centralized OTP logging with correct status display."""

    # ANSI color codes
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"
    WHITE = "\033[37m"

    @classmethod
    def _sep(cls, char: str = "─", width: int = 70) -> str:
        return char * width

    @classmethod
    def _box_text(cls, text: str, width: int = 68, color: str = "") -> str:
        padding = width - len(text)
        left = padding // 2
        right = padding - left
        return f"{color}║{' ' * left}{text}{' ' * right}║{cls.RESET}"

    # ============================================================
    # ✅ MAIN METHOD: Full OTP Dispatch Report
    # ============================================================
    @classmethod
    def log_otp_dispatch(
        cls,
        purpose: str,
        email: Optional[str],
        mobile: Optional[str],
        email_otp: Optional[str],
        mobile_otp: Optional[str],
        results: Dict[str, bool],
        mode: str = "DEVELOPMENT",
        timestamp: Optional[datetime] = None,
        skipped_channels: Optional[Dict[str, str]] = None,
    ) -> None:
        """
        Display box-formatted OTP report with ACCURATE status.

        Args:
            purpose: Purpose of OTP (registration, password reset, etc.)
            email: Email address
            mobile: Mobile number
            email_otp: The email OTP that was sent
            mobile_otp: The mobile OTP that was sent (or bypassed)
            results: Dict with keys email/sms/whatsapp and bool values
            mode: "DEVELOPMENT" or "PRODUCTION"
            timestamp: Optional custom timestamp
            skipped_channels: Dict showing why channels were skipped
                              e.g. {"whatsapp": "Provider disabled"}
        """
        ts = (timestamp or datetime.now()).strftime("%Y-%m-%d %H:%M:%S")
        skipped_channels = skipped_channels or {}

        # Mode color/icon
        if mode.upper() == "DEVELOPMENT":
            mode_color = cls.YELLOW
            mode_icon = "🔧"
        else:
            mode_color = cls.GREEN
            mode_icon = "🔴"

        # ============================================================
        # HEADER
        # ============================================================
        print()
        print(f"{cls.CYAN}{cls.BOLD}{cls._sep('═')}{cls.RESET}")
        print(f"{cls.CYAN}{cls.BOLD}╔{'═' * 68}╗{cls.RESET}")
        print(cls._box_text("📢 OTP DISPATCH REPORT", 68, f"{cls.CYAN}{cls.BOLD}"))
        print(f"{cls.CYAN}{cls.BOLD}╚{'═' * 68}╝{cls.RESET}")
        print(f"  {cls.BOLD}🎯 Purpose:{cls.RESET}      {cls.CYAN}{purpose.upper()}{cls.RESET}")
        print(f"  {cls.BOLD}⏰ Time:{cls.RESET}         {ts}")
        print(f"  {cls.BOLD}{mode_icon} Mode:{cls.RESET}         {mode_color}{mode}{cls.RESET}")
        print(f"{cls.DIM}{cls._sep('─')}{cls.RESET}")

        # ============================================================
        # 📧 EMAIL OTP
        # ============================================================
        print(f"  {cls.BOLD}📧 EMAIL OTP{cls.RESET}")
        print(f"{cls.DIM}{cls._sep('─')}{cls.RESET}")

        if email_otp and email:
            email_sent = results.get("email", False)
            if email_sent:
                icon = "✅"
                text = "SENT SUCCESSFULLY"
                color = cls.GREEN
            else:
                icon = "❌"
                text = "FAILED"
                color = cls.RED

            print(f"     To:     {cls.CYAN}{email}{cls.RESET}")
            print(f"     OTP:    {cls.BOLD}{cls.YELLOW}{email_otp}{cls.RESET}  "
                  f"{cls.DIM}(ALWAYS REAL){cls.RESET}")
            print(f"     Status: {color}{icon} {text}{cls.RESET}")
        else:
            reason = skipped_channels.get("email", "No email provided")
            print(f"     {cls.DIM}⊘ SKIPPED ({reason}){cls.RESET}")

        print()

        # ============================================================
        # 📱 SMS OTP
        # ============================================================
        print(f"  {cls.BOLD}📱 SMS OTP{cls.RESET}")
        print(f"{cls.DIM}{cls._sep('─')}{cls.RESET}")

        if mobile and mobile_otp:
            sms_result = results.get("sms", False)

            if mode.upper() == "DEVELOPMENT":
                print(f"     To:     {cls.CYAN}+91{mobile}{cls.RESET}")
                print(f"     OTP:    {cls.BOLD}{cls.YELLOW}{mobile_otp}{cls.RESET}  "
                      f"{cls.YELLOW}(BYPASSED){cls.RESET}")
                print(f"     Status: {cls.YELLOW}🔧 BYPASSED (no real SMS sent){cls.RESET}")
                print(f"     {cls.DIM}→ Use {cls.YELLOW}{mobile_otp}{cls.DIM} "
                      f"or any 6-digit for verification{cls.RESET}")
            else:
                if sms_result:
                    icon = "✅"
                    text = "SENT SUCCESSFULLY"
                    color = cls.GREEN
                else:
                    icon = "❌"
                    text = "FAILED"
                    color = cls.RED

                print(f"     To:     {cls.CYAN}+91{mobile}{cls.RESET}")
                print(f"     OTP:    {cls.BOLD}{cls.YELLOW}{mobile_otp}{cls.RESET}")
                print(f"     Status: {color}{icon} {text}{cls.RESET}")
        else:
            reason = skipped_channels.get("sms", "No mobile provided")
            print(f"     {cls.DIM}⊘ SKIPPED ({reason}){cls.RESET}")

        print()

        # ============================================================
        # 💬 WHATSAPP OTP - CORRECTED LOGIC
        # ============================================================
        print(f"  {cls.BOLD}💬 WHATSAPP OTP{cls.RESET}")
        print(f"{cls.DIM}{cls._sep('─')}{cls.RESET}")

        if mobile and mobile_otp:
            wa_result = results.get("whatsapp", False)
            wa_skipped = skipped_channels.get("whatsapp")

            if mode.upper() == "DEVELOPMENT":
                print(f"     To:     {cls.CYAN}+91{mobile}{cls.RESET}")
                print(f"     OTP:    {cls.BOLD}{cls.YELLOW}{mobile_otp}{cls.RESET}  "
                      f"{cls.YELLOW}(BYPASSED){cls.RESET}")
                print(f"     Status: {cls.YELLOW}🔧 BYPASSED (no real WhatsApp sent){cls.RESET}")
            elif wa_skipped:
                print(f"     To:     {cls.CYAN}+91{mobile}{cls.RESET}")
                print(f"     OTP:    {cls.BOLD}{cls.YELLOW}{mobile_otp}{cls.RESET}")
                print(f"     Status: {cls.YELLOW}⊘ SKIPPED{cls.RESET}")
                print(f"     Reason: {cls.DIM}{wa_skipped}{cls.RESET}")
            elif wa_result:
                print(f"     To:     {cls.CYAN}+91{mobile}{cls.RESET}")
                print(f"     OTP:    {cls.BOLD}{cls.YELLOW}{mobile_otp}{cls.RESET}")
                print(f"     Status: {cls.GREEN}✅ SENT SUCCESSFULLY{cls.RESET}")
            else:
                print(f"     To:     {cls.CYAN}+91{mobile}{cls.RESET}")
                print(f"     OTP:    {cls.BOLD}{cls.YELLOW}{mobile_otp}{cls.RESET}")
                print(f"     Status: {cls.RED}❌ FAILED{cls.RESET}")
        else:
            reason = skipped_channels.get("whatsapp", "No mobile provided")
            print(f"     {cls.DIM}⊘ SKIPPED ({reason}){cls.RESET}")

        print()

        # ============================================================
        # 📊 SUMMARY
        # ============================================================
        email_status = "✅ SENT" if results.get("email") else ("❌ FAILED" if email else "⊘ SKIPPED")

        if mode.upper() == "DEVELOPMENT" and mobile:
            sms_status = "🔧 BYPASSED"
            wa_status = "🔧 BYPASSED"
        else:
            sms_status = "✅ SENT" if results.get("sms") else ("❌ FAILED" if mobile else "⊘ SKIPPED")
            if skipped_channels.get("whatsapp"):
                wa_status = "⊘ SKIPPED"
            else:
                wa_status = "✅ SENT" if results.get("whatsapp") else ("❌ FAILED" if mobile else "⊘ SKIPPED")

        print(f"{cls.DIM}{cls._sep('─')}{cls.RESET}")
        print(f"  {cls.BOLD}📊 SUMMARY{cls.RESET}")
        print(f"     Email:    {email_status}")
        print(f"     SMS:      {sms_status}")
        print(f"     WhatsApp: {wa_status}")
        print(f"{cls.CYAN}{cls.BOLD}{cls._sep('═')}{cls.RESET}")
        print()

    # ============================================================
    # COMPACT: One-line generation log
    # ============================================================
    @classmethod
    def log_otp_generation(
        cls,
        purpose: str,
        email_otp: str,
        mobile_otp: str,
        mode: str = "DEVELOPMENT",
    ) -> None:
        mode_icon = "🔧" if mode.upper() == "DEVELOPMENT" else "🔴"
        print(
            f"{cls.DIM}[OTP GEN]{cls.RESET} {mode_icon} "
            f"Purpose={cls.CYAN}{purpose}{cls.RESET} | "
            f"Email OTP={cls.YELLOW}{cls.BOLD}{email_otp}{cls.RESET} | "
            f"Mobile OTP={cls.YELLOW}{cls.BOLD}{mobile_otp}{cls.RESET} | "
            f"Mode={mode}"
        )

    @classmethod
    def log_email_otp(cls, email: str, otp: str, success: bool = True) -> None:
        icon = "✅" if success else "❌"
        color = cls.GREEN if success else cls.RED
        print(
            f"{color}{icon} [EMAIL OTP]{cls.RESET} "
            f"To={cls.CYAN}{email}{cls.RESET} | "
            f"OTP={cls.YELLOW}{cls.BOLD}{otp}{cls.RESET} | "
            f"Status={'SENT' if success else 'FAILED'}"
        )

    @classmethod
    def log_sms_otp(cls, mobile: str, otp: str, success: bool = True, bypassed: bool = False) -> None:
        if bypassed:
            print(
                f"{cls.YELLOW}🔧 [SMS OTP - BYPASSED]{cls.RESET} "
                f"To={cls.CYAN}+91{mobile}{cls.RESET} | "
                f"OTP={cls.YELLOW}{cls.BOLD}{otp}{cls.RESET}"
            )
        else:
            icon = "✅" if success else "❌"
            color = cls.GREEN if success else cls.RED
            print(
                f"{color}{icon} [SMS OTP]{cls.RESET} "
                f"To={cls.CYAN}+91{mobile}{cls.RESET} | "
                f"OTP={cls.YELLOW}{cls.BOLD}{otp}{cls.RESET} | "
                f"Status={'SENT' if success else 'FAILED'}"
            )

    @classmethod
    def log_whatsapp_otp(
        cls,
        mobile: str,
        otp: str,
        success: bool = True,
        bypassed: bool = False,
        skipped_reason: Optional[str] = None,
    ) -> None:
        if bypassed:
            print(
                f"{cls.YELLOW}🔧 [WHATSAPP OTP - BYPASSED]{cls.RESET} "
                f"To={cls.CYAN}+91{mobile}{cls.RESET} | "
                f"OTP={cls.YELLOW}{cls.BOLD}{otp}{cls.RESET}"
            )
        elif skipped_reason:
            print(
                f"{cls.YELLOW}⊘ [WHATSAPP OTP - SKIPPED]{cls.RESET} "
                f"To={cls.CYAN}+91{mobile}{cls.RESET} | "
                f"Reason={cls.DIM}{skipped_reason}{cls.RESET}"
            )
        else:
            icon = "✅" if success else "❌"
            color = cls.GREEN if success else cls.RED
            print(
                f"{color}{icon} [WHATSAPP OTP]{cls.RESET} "
                f"To={cls.CYAN}+91{mobile}{cls.RESET} | "
                f"OTP={cls.YELLOW}{cls.BOLD}{otp}{cls.RESET} | "
                f"Status={'SENT' if success else 'FAILED'}"
            )


# Global instance
otp_logger = OTPLogger()

print("=" * 70)
print("✅ OTP Terminal Logger Loaded (with skipped_channels support)")
print("   - Correct status display (no false success)")
print("   - Full box-formatted reports")
print("   - Compact one-line logs")
print("=" * 70)