#!/usr/bin/env python3
"""
Build docs/grok-build-invoice-commerce-demo.gif
Order → invoice → PDF → AR payment demo for /business-bookkeeper.

Matches visual language of docs/grok-build-bookkeeper-demo.gif (1280×720 dark UI).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
W, H = 1280, 720
BG = (18, 18, 22)
PANEL = (28, 30, 36)
HEADER = (24, 26, 32)
GREEN = (44, 160, 28)
CYAN = (0, 212, 170)
GOLD = (240, 185, 50)
WHITE = (240, 240, 245)
MUTED = (140, 145, 155)
RED = (220, 90, 90)
CODE_BG = (12, 14, 18)

OUT_DIR = ROOT / "tmp" / "invoice-demo-frames"
GIF_TMP = ROOT / "tmp" / "grok-build-invoice-commerce-demo.gif"
GIF_DOCS = ROOT / "docs" / "grok-build-invoice-commerce-demo.gif"
DEMO_DB = Path("/tmp/business-invoice-demo.sqlite3")
PDF_PATH = Path("/tmp/invoice-demo-INV.pdf")
PDF_PNG = Path("/tmp/invoice-demo-pdf-page.png")

FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
FONT_MONO_B = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def run(cmd: list[str] | str, env: dict | None = None, shell: bool = False) -> str:
    e = os.environ.copy()
    if env:
        e.update(env)
    r = subprocess.run(
        cmd,
        shell=shell,
        capture_output=True,
        text=True,
        env=e,
        cwd=str(ROOT),
    )
    out = (r.stdout or "") + (("\n" + r.stderr) if r.returncode and r.stderr else "")
    return out.strip()


def bash_env() -> dict:
    return {
        "SQLITE_DB": str(DEMO_DB),
        "PATH": f"{ROOT}/Bash/sqlite:" + os.environ.get("PATH", ""),
    }


def new_frame() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    im = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(im)
    # top bar
    d.rectangle([0, 0, W, 52], fill=HEADER)
    d.text((28, 14), "Grok Build", font=font(FONT_BOLD, 22), fill=CYAN)
    d.text((200, 18), "·  /business-bookkeeper  ·  skill demo", font=font(FONT_REG, 16), fill=MUTED)
    return im, d


def draw_title_card(lines: list[tuple[str, str, int]]) -> Image.Image:
    """lines: (text, color_name, size)"""
    im, d = new_frame()
    y = 160
    for text, color, size in lines:
        col = {"white": WHITE, "cyan": CYAN, "gold": GOLD, "muted": MUTED, "green": GREEN}[color]
        f = font(FONT_BOLD if size >= 28 else FONT_REG, size)
        # center-ish
        bbox = d.textbbox((0, 0), text, font=f)
        tw = bbox[2] - bbox[0]
        d.text(((W - tw) // 2, y), text, font=f, fill=col)
        y += size + 18
    return im


def draw_step(
    step: str,
    prompt: str,
    terminal: str,
    footer: str = "",
    side_image: Path | None = None,
) -> Image.Image:
    im, d = new_frame()
    # step badge
    d.rounded_rectangle([28, 72, 220, 108], radius=8, fill=(40, 50, 45))
    d.text((40, 80), step, font=font(FONT_BOLD, 16), fill=GREEN)

    # user prompt bubble
    d.text((28, 122), "You", font=font(FONT_BOLD, 14), fill=MUTED)
    d.rounded_rectangle([28, 144, W - 28, 210], radius=10, fill=(35, 40, 55))
    # wrap prompt
    f = font(FONT_REG, 20)
    y = 158
    for line in textwrap.wrap(prompt, width=90):
        d.text((48, y), line, font=f, fill=WHITE)
        y += 26

    # terminal / output panel
    panel_top = 230
    panel_bot = H - 70 if not footer else H - 100
    if side_image and side_image.exists():
        # left terminal, right image
        d.rounded_rectangle([28, panel_top, 700, panel_bot], radius=10, fill=CODE_BG)
        d.text((44, panel_top + 12), "terminal", font=font(FONT_REG, 12), fill=MUTED)
        mono = font(FONT_MONO, 15)
        ty = panel_top + 36
        for line in terminal.splitlines()[:18]:
            if len(line) > 72:
                line = line[:69] + "…"
            d.text((44, ty), line, font=mono, fill=(180, 220, 180) if line.startswith("$") or line.startswith("→") else WHITE)
            ty += 20
            if ty > panel_bot - 20:
                break
        # paste PDF preview
        prev = Image.open(side_image).convert("RGB")
        # fit right panel
        box_w, box_h = 500, panel_bot - panel_top - 20
        prev.thumbnail((box_w, box_h), Image.Resampling.LANCZOS)
        px = W - 28 - prev.width
        py = panel_top + (panel_bot - panel_top - prev.height) // 2
        d.rounded_rectangle([px - 8, panel_top, W - 28, panel_bot], radius=10, fill=(40, 40, 44))
        im.paste(prev, (px, py))
        d.text((px, panel_top + 8), "invoice PDF", font=font(FONT_REG, 12), fill=MUTED)
    else:
        d.rounded_rectangle([28, panel_top, W - 28, panel_bot], radius=10, fill=CODE_BG)
        d.text((44, panel_top + 12), "terminal", font=font(FONT_REG, 12), fill=MUTED)
        mono = font(FONT_MONO, 16)
        ty = panel_top + 40
        for line in terminal.splitlines()[:20]:
            if len(line) > 110:
                line = line[:107] + "…"
            color = WHITE
            if line.startswith("$") or line.startswith("→"):
                color = CYAN
            elif "Total" in line or "BALANCE" in line or "Receivable" in line or "Sales" in line:
                color = GOLD
            elif line.startswith("Error"):
                color = RED
            d.text((48, ty), line, font=mono, fill=color)
            ty += 22
            if ty > panel_bot - 16:
                break

    if footer:
        d.text((28, H - 48), footer, font=font(FONT_REG, 15), fill=MUTED)
    return im


def save_frames(frames: list[Image.Image]) -> None:
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    OUT_DIR.mkdir(parents=True)
    for i, im in enumerate(frames):
        im.save(OUT_DIR / f"frame_{i:03d}.png")


def assemble_gif(n_frames: int, durations_ms: list[int]) -> None:
    # Use ffmpeg for palette-friendly gif
    # Build concat with durations via filter or magick
    # ImageMagick: convert -delay centiseconds
    args = ["magick", "-loop", "0"]
    for i, dur in enumerate(durations_ms):
        # delay is in 1/100 s
        delay = max(1, dur // 10)
        args += ["-delay", str(delay), str(OUT_DIR / f"frame_{i:03d}.png")]
    args += ["-layers", "Optimize", str(GIF_TMP)]
    subprocess.check_call(args)
    GIF_DOCS.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(GIF_TMP, GIF_DOCS)
    print(f"Wrote {GIF_DOCS} ({GIF_DOCS.stat().st_size} bytes)")


def seed_demo() -> dict:
    """Create parts, order, invoice, PDF, payment. Return paths and outputs."""
    template = ROOT / "business.sqlite3"
    if not template.exists():
        template = Path.home() / "business-shop" / "business.sqlite3.pristine-0.2.9"
    shutil.copy2(template, DEMO_DB)
    env = bash_env()

    def sh(cmd: str) -> str:
        return run(["bash", "-lc", cmd], env=env)

    # Parties
    sh("GetIndividualEntity 'Bunnies-R-Us'")
    sh("GetIndividualEntity 'City Library'")
    sh("SetIndividualEmail $(GetIndividualEntity 'Bunnies-R-Us') 'billing@bunnies-r-us.example' Work")
    sh("SetIndividualEmail $(GetIndividualEntity 'City Library') 'orders@citylibrary.example' Work")
    sh("GetPostal USA 10504 Armonk NY 'New York'")
    sh("GetPostal USA 20500 Washington DC 'District of Columbia'")
    sh("SetIndividualAddress $(GetIndividualEntity 'Bunnies-R-Us') $(GetAddress '1 New Orchard Road' 10504 1716) Primary")
    sh("SetIndividualAddress $(GetIndividualEntity 'City Library') $(GetAddress '1600 Pennsylvania Avenue NW' 20500 0005) Billing")
    sh("SetIndividualPhone $(GetIndividualEntity 'Bunnies-R-Us') $(GetPhone USA 914 4991900) Work")
    sh("SetIndividualPhone $(GetIndividualEntity 'City Library') $(GetPhone USA 202 4561111) Work")

    # Inventory catalog: Product / SKU → Widget-A, Gadget-B (same pattern as Resistor / 0603)
    sh("GetPart Product")
    w_a = sh("GetPartWithParent Widget-A 1.0 Product SKU")
    g_b = sh("GetPartWithParent Gadget-B 2.0 Product SKU")
    if not w_a or not g_b:
        raise SystemExit(f"part create failed: Widget-A={w_a!r} Gadget-B={g_b!r}")

    list_parts = sh(
        'sqlite3 "$SQLITE_DB" '
        "\"SELECT part, name, version FROM Parts "
        "WHERE name IN ('Widget-A','Gadget-B','Product') ORDER BY part;\""
    )

    sup = sh("GetIndividualEntity 'Bunnies-R-Us'")
    con = sh("GetIndividualEntity 'City Library'")

    # Cart → Quote → Order → Invoice (skip wish for shorter demo)
    cart = sh(f"CreateBill {sup} {con} Cart")
    sh(f"AddCargo {cart} {w_a} 3")
    sh(f"AddCargo {cart} {g_b} 1")
    job = sh("GetJob Default")
    sch = sh("GetSchedule Default")
    ij = sh(f"GetIndividualJobSchedule {con} {job} {sch}")
    sh(f"""sqlite3 "$SQLITE_DB" "INSERT INTO Schedule (schedule, fromCount, toCount, rate) SELECT {sch}, 0, 999, 100 WHERE NOT EXISTS (SELECT 1 FROM Schedule WHERE schedule={sch} LIMIT 1);" """)
    sh(f"PutAssemblyJobPrice {w_a} {ij} 12.50")
    sh(f"PutAssemblyJobPrice {g_b} {ij} 49.00")

    quote = sh(f"CreateBill {sup} {con} Quote {cart}")
    sh(f"MoveCargoToChild {cart} '' '' {ij}")
    order = sh(f"CreateBill {sup} {con} Order {quote}")
    sh(f"MoveCargoToChild {quote} '' '' '' 'AR Sale'")
    inv = sh(f"CreateBill {sup} {con} Invoice {order}")
    sh(f"MoveCargoToChild {order}")
    sh(f"GetBillReference {inv} 'PO Number' 'PO-LIB-77'")

    lines_before_pay = sh(f"DocumentLineItems {inv}")
    pdf_out = sh(f"InvoicePDF {inv} {PDF_PATH}")
    # render pdf page
    run(["pdftoppm", "-png", "-r", "120", "-f", "1", "-l", "1", str(PDF_PATH), str(PDF_PNG.with_suffix(""))])
    # pdftoppm adds -1
    png = Path(str(PDF_PNG.with_suffix("")) + "-1.png")
    if png.exists():
        shutil.copy2(png, PDF_PNG)

    # Payment
    rcp = sh(f"CreateBill {sup} {con} Receipt {inv}")
    sh(f"MoveCargoToChild {inv} '' '' '' 'AR Payment'")
    journal = sh("JournalReport 1")
    lines_after = sh(f"DocumentLineItems {rcp}")

    return {
        "w_a": w_a,
        "g_b": g_b,
        "list_parts": list_parts,
        "cart": cart,
        "order": order,
        "inv": inv,
        "rcp": rcp,
        "lines_before_pay": lines_before_pay,
        "lines_after": lines_after,
        "journal": journal,
        "pdf": pdf_out,
        "parts_ids": f"Widget-A → {w_a}\nGadget-B → {g_b}",
    }


def main() -> None:
    print("Seeding demo database…")
    info = seed_demo()
    frames: list[Image.Image] = []
    durs: list[int] = []

    # 0 title
    frames.append(
        draw_title_card(
            [
                ("Grok Build as your small", "white", 36),
                ("business bookkeeper", "cyan", 36),
                ("Order → Invoice → PDF → Payment", "gold", 26),
                ("skill: /business-bookkeeper", "white", 22),
                ("Business schema  ·  true double-entry AR", "muted", 18),
            ]
        )
    )
    durs.append(3200)

    # 1 inventory
    frames.append(
        draw_step(
            "Step 1 · Inventory",
            "Add two products to the catalog: Widget-A and Gadget-B.",
            "$ GetPart Product\n"
            "$ GetPartWithParent Widget-A 1.0 Product SKU\n"
            f"→ {info['w_a']}\n"
            "$ GetPartWithParent Gadget-B 2.0 Product SKU\n"
            f"→ {info['g_b']}\n\n"
            f"{info['list_parts']}",
            footer="Find-or-insert parts (NoCRUD) — catalog ready to sell",
        )
    )
    durs.append(3800)

    # 2 order
    frames.append(
        draw_step(
            "Step 2 · Customer order",
            "City Library orders 3× Widget-A and 1× Gadget-B. Quote locks prices; create Order.",
            f"$ CreateBill Bunnies-R-Us City Library Cart\n"
            f"→ cart {info['cart']}\n"
            f"$ AddCargo … Widget-A ×3 · Gadget-B ×1\n"
            f"$ PutAssemblyJobPrice Widget-A $12.50 · Gadget-B $49.00\n"
            f"$ CreateBill … Quote → Order\n"
            f"$ MoveCargoToChild … book AR Sale\n"
            f"→ order {info['order']}\n\n"
            "Line total: 3×12.50 + 1×49.00 = $86.50",
            footer="Cargo moves Cart → Quote → Order · AR Sale books Receivable / Sales",
        )
    )
    durs.append(4200)

    # 3 invoice
    frames.append(
        draw_step(
            "Step 3 · Invoice",
            "Convert the order into an invoice for the customer.",
            f"$ CreateBill … Invoice (parent = Order {info['order']})\n"
            f"→ invoice {info['inv']}\n"
            f"$ MoveCargoToChild from Order\n"
            f"$ GetBillReference {info['inv']} 'PO Number' PO-LIB-77\n\n"
            f"{info['lines_before_pay']}",
            footer="Invoice lines lock quoted unit prices · outstanding qty still open",
        )
    )
    durs.append(4000)

    # 4 PDF
    frames.append(
        draw_step(
            "Step 4 · PDF invoice",
            "Create a QuickBooks-style PDF and save it under the shop.",
            f"$ InvoicePDF {info['inv']}\n"
            f"→ {info['pdf']}\n\n"
            "Layout: company header · Bill To · line table ·\n"
            "subtotal / tax $0 / total / balance due\n"
            "(tax & logo not in schema yet — noted as limitations)",
            footer="Default path: ~/business-shop/invoices/invoice-NNNNN.pdf",
            side_image=PDF_PNG if PDF_PNG.exists() else None,
        )
    )
    durs.append(4500)

    # 5 PDF focus (full terminal note)
    frames.append(
        draw_step(
            "Step 4b · Invoice preview",
            "Customer-facing document ready to send (file only — skill does not email).",
            "INVOICE  INV-%05d\n"
            "Bill To: City Library\n"
            "3 × Widget-A @ $12.50\n"
            "1 × Gadget-B @ $49.00\n"
            "─────────────────────\n"
            "Total / Balance due   $86.50\n"
            % int(info["inv"]),
            footer="PDF is a view of books — source of truth remains Bill + LineItems + Journal",
            side_image=PDF_PNG if PDF_PNG.exists() else None,
        )
    )
    durs.append(3500)

    # 6 payment
    frames.append(
        draw_step(
            "Step 5 · Customer payment",
            "Record that City Library paid the invoice in full.",
            f"$ CreateBill … Receipt (parent = Invoice {info['inv']})\n"
            f"→ receipt {info['rcp']}\n"
            f"$ MoveCargoToChild … book AR Payment\n\n"
            "AR Payment book: Debit Cash · Credit Receivable",
            footer="Receipt child clears cargo · cash collected against AR",
        )
    )
    durs.append(3800)

    # 7 journal / sales accounts
    # trim journal to relevant lines
    jlines = []
    for line in info["journal"].splitlines():
        if any(
            x in line
            for x in (
                "Receivable",
                "Sales",
                "Cash",
                "Total",
                "account",
                "---",
                "entry",
            )
        ):
            jlines.append(line)
    jtxt = "\n".join(jlines[-16:]) if jlines else info["journal"][-800:]

    frames.append(
        draw_step(
            "Step 6 · Sales accounts",
            "Show the journal — debits equal credits (true double-entry).",
            f"$ JournalReport\n\n{jtxt}",
            footer="AR Sale then AR Payment · Receivable up then down · Sales income recognized",
        )
    )
    durs.append(4500)

    # 8 end card
    frames.append(
        draw_title_card(
            [
                ("Inventory · Order · Invoice · PDF · Pay", "cyan", 28),
                ("Enable Grok Build to do true", "white", 30),
                ("double-entry accounting!", "gold", 30),
                ("/business-bookkeeper", "white", 24),
                ("Limitations noted: tax, logo, ship/BOL — expand when needed", "muted", 16),
            ]
        )
    )
    durs.append(3500)

    print(f"Saving {len(frames)} frames…")
    save_frames(frames)
    assemble_gif(len(frames), durs)
    print("Done.")


if __name__ == "__main__":
    main()
