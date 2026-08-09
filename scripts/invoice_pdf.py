#!/usr/bin/env python3
"""
Render a QuickBooks-style invoice PDF from a Business schema bill (Invoice or Order).

Reads views: Bills, LineItems, Entities/People, Addresses, EmailAddress, Phones,
BillReference. No new tables required.

Usage:
  SQLITE_DB=~/business-shop/business.sqlite3 \\
    python3 scripts/invoice_pdf.py <bill_id> [output.pdf]

Default output: ~/business-shop/invoices/invoice-<bill_id>.pdf
"""
from __future__ import annotations

import os
import sqlite3
import sys
from datetime import datetime, timedelta
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    HRFlowable,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

# QuickBooks-ish palette
QB_GREEN = colors.HexColor("#2CA01C")
QB_DARK = colors.HexColor("#1A1A1A")
QB_GRAY = colors.HexColor("#6B6B6B")
QB_LINE = colors.HexColor("#D5D5D5")
QB_HEADER_BG = colors.HexColor("#F4F5F8")
QB_TOTAL_BG = colors.HexColor("#E8F5E9")


def money(n) -> str:
    if n is None:
        return ""
    try:
        return f"${float(n):,.2f}"
    except (TypeError, ValueError):
        return str(n)


def party_name(conn: sqlite3.Connection, individual_id: int) -> str:
    row = conn.execute(
        """
        SELECT COALESCE(
          (SELECT name FROM Entities WHERE individual = ?),
          (SELECT fullName FROM People WHERE individual = ?),
          'Individual ' || ?
        ) AS name
        """,
        (individual_id, individual_id, individual_id),
    ).fetchone()
    return (row[0] if row else f"Individual {individual_id}") or ""


def party_email(conn: sqlite3.Connection, individual_id: int) -> str:
    row = conn.execute(
        """
        SELECT e.username
          || CASE WHEN e.plus IS NOT NULL THEN '+' || e.plus ELSE '' END
          || '@' || e.host
        FROM IndividualEmail ie
        JOIN Email e ON e.id = ie.email
        WHERE ie.individual = ? AND ie.stop IS NULL
        ORDER BY ie.created DESC
        LIMIT 1
        """,
        (individual_id,),
    ).fetchone()
    return row[0] if row else ""


def party_phone(conn: sqlite3.Connection, individual_id: int) -> str:
    if _has_view(conn, "PartyPhones"):
        row = conn.execute(
            """
            SELECT local FROM PartyPhones
            WHERE individual = ?
            ORDER BY created DESC LIMIT 1
            """,
            (individual_id,),
        ).fetchone()
        if row and row[0]:
            return row[0]
    row = conn.execute(
        """
        SELECT p.local
        FROM IndividualPhone ip
        JOIN Phones p ON p.phone = ip.phone
        WHERE ip.individual = ? AND ip.stop IS NULL
        LIMIT 1
        """,
        (individual_id,),
    ).fetchone()
    if row:
        return row[0]
    row = conn.execute(
        """
        SELECT ph.area || '-' || ph.number
        FROM IndividualPhone ip
        JOIN Phone ph ON ph.id = ip.phone
        WHERE ip.individual = ? AND ip.stop IS NULL
        LIMIT 1
        """,
        (individual_id,),
    ).fetchone()
    return row[0] if row else ""


def _has_view(conn: sqlite3.Connection, name: str) -> bool:
    """True if view/table is queryable (SQLite master or SELECT probe for other engines)."""
    try:
        row = conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type IN ('view','table') AND name = ? LIMIT 1",
            (name,),
        ).fetchone()
        if row:
            return True
    except Exception:
        pass
    try:
        conn.execute(f"SELECT 1 FROM {name} LIMIT 0")
        return True
    except Exception:
        return False


def party_address_block(conn: sqlite3.Connection, individual_id: int, prefer: str | None = None) -> list[str]:
    """Return address lines (street, city state zip). prefer: Billing/Shipping/Primary word."""
    row = None
    if _has_view(conn, "PartyAddresses"):
        if prefer:
            row = conn.execute(
                """
                SELECT line1, line2, city, state, zipcode, countrycode
                FROM PartyAddresses
                WHERE individual = ?
                ORDER BY CASE WHEN addressType = ? THEN 0 ELSE 1 END, created DESC
                LIMIT 1
                """,
                (individual_id, prefer),
            ).fetchone()
        else:
            row = conn.execute(
                """
                SELECT line1, line2, city, state, zipcode, countrycode
                FROM PartyAddresses
                WHERE individual = ?
                ORDER BY created DESC
                LIMIT 1
                """,
                (individual_id,),
            ).fetchone()
    if not row:
        params: list = [individual_id]
        prefer_sql = " ORDER BY ia.created DESC "
        if prefer:
            prefer_sql = """
              ORDER BY CASE WHEN w.value = ? THEN 0 ELSE 1 END, ia.created DESC
            """
            params.append(prefer)
        row = conn.execute(
            f"""
            SELECT a.line1, a.line2, a.city, a.state, a.zipcode, a.countryCode
            FROM IndividualAddress ia
            JOIN Addresses a ON a.address = ia.address
            LEFT JOIN Word w ON w.id = ia.type
            WHERE ia.individual = ? AND ia.stop IS NULL
            {prefer_sql}
            LIMIT 1
            """,
            params if not prefer else [individual_id, prefer],
        ).fetchone()
    if not row:
        return []
    line1, line2, city, state, zipcode, country = row
    lines = []
    if line1:
        lines.append(line1)
    if line2:
        lines.append(line2)
    # "City, ST ZIP" (QuickBooks-style)
    loc = ""
    if city and state:
        loc = f"{city}, {state}"
    elif city or state:
        loc = city or state
    if zipcode:
        loc = f"{loc} {zipcode}".strip()
    if loc:
        lines.append(loc)
    if country and country not in ("USA", "US"):
        lines.append(country)
    return lines


def bill_references(conn: sqlite3.Connection, bill_id: int) -> list[tuple[str, str]]:
    if _has_view(conn, "BillReferences"):
        rows = conn.execute(
            """
            SELECT COALESCE(referenceType, 'Ref'), value
            FROM BillReferences
            WHERE bill = ?
            ORDER BY (sequence IS NULL), sequence, id
            """,
            (bill_id,),
        ).fetchall()
        return [(r[0], r[1]) for r in rows]
    rows = conn.execute(
        """
        SELECT COALESCE(w.value, 'Ref'), br.value
        FROM BillReference br
        LEFT JOIN Word w ON w.id = br.type AND w.culture IS NULL
        WHERE br.bill = ? AND br.stop IS NULL
        ORDER BY (br.sequence IS NULL), br.sequence, br.id
        """,
        (bill_id,),
    ).fetchall()
    return [(r[0], r[1]) for r in rows]


def load_invoice(conn: sqlite3.Connection, bill_id: int) -> dict:
    bill = None
    inv_number = None
    if _has_view(conn, "BillDocuments"):
        bill = conn.execute(
            """
            SELECT bill, documentType, documentDate, supplier, supplierName,
                   consignee, consigneeName, parent, parentType, invoiceNumber, subtotal
            FROM BillDocuments
            WHERE bill = ?
            """,
            (bill_id,),
        ).fetchone()
        if bill:
            inv_number = bill[9]
    if not bill:
        bill = conn.execute(
            """
            SELECT bill, type, date, supplier, supplierName, consignee, consigneeName, parent, parentType
            FROM Bills
            WHERE bill = ?
            """,
            (bill_id,),
        ).fetchone()
    if not bill:
        raise SystemExit(f"No bill id {bill_id} in BillDocuments/Bills")

    b = {
        "bill": bill[0],
        "type": bill[1],
        "date": bill[2],
        "supplier": bill[3],
        "supplierName": bill[4],
        "consignee": bill[5],
        "consigneeName": bill[6],
        "parent": bill[7],
        "parentType": bill[8],
        "invoice_number": inv_number or f"INV-{int(bill[0]):05d}",
    }

    if _has_view(conn, "InvoiceLineDetail"):
        lines = conn.execute(
            """
            SELECT line, product, qty, rate, currentUnitPrice, amount, outstanding, description
            FROM InvoiceLineDetail
            WHERE bill = ?
            ORDER BY line
            """,
            (bill_id,),
        ).fetchall()
        b["lines"] = [
            {
                "line": r[0],
                "item": r[1],
                "count": r[2] if r[2] is not None else 1,
                "unit": r[3] if r[3] is not None else r[4],
                "total": r[5],
                "outstanding": r[6],
                "version": r[7],
            }
            for r in lines
        ]
    else:
        lines = conn.execute(
            """
            SELECT line, item, count, unitPrice, currentUnitPrice, totalPrice, outstanding, version
            FROM LineItems
            WHERE bill = ?
            ORDER BY line
            """,
            (bill_id,),
        ).fetchall()
        b["lines"] = [
            {
                "line": r[0],
                "item": r[1],
                "count": r[2] if r[2] is not None else 1,
                "unit": r[3] if r[3] is not None else r[4],
                "total": r[5],
                "outstanding": r[6],
                "version": r[7],
            }
            for r in lines
        ]

    # Subtotal from line totals (unit * count when total null)
    subtotal = 0.0
    for ln in b["lines"]:
        if ln["total"] is not None:
            subtotal += float(ln["total"])
        elif ln["unit"] is not None:
            subtotal += float(ln["unit"]) * float(ln["count"] or 1)
    b["subtotal"] = subtotal
    b["tax"] = 0.0  # no tax schedule in schema yet
    b["total"] = subtotal + b["tax"]

    # Payments: sum Receipt children cargo booked? Simple: if type is Invoice and no receipt child with AR Payment, 0
    paid = conn.execute(
        """
        SELECT COALESCE(SUM(li.totalPrice), 0)
        FROM Bills child
        JOIN LineItems li ON li.bill = child.bill
        WHERE child.parent = ?
          AND child.type = 'Receipt'
        """,
        (bill_id,),
    ).fetchone()
    b["amount_paid"] = float(paid[0] or 0) if paid else 0.0
    # If this bill itself is already a receipt, paid = total
    if (b["type"] or "").lower() == "receipt":
        b["amount_paid"] = b["total"]
    b["balance_due"] = max(0.0, b["total"] - b["amount_paid"])

    b["supplier_display"] = party_name(conn, b["supplier"]) or b["supplierName"]
    b["consignee_display"] = party_name(conn, b["consignee"]) or b["consigneeName"]
    b["supplier_email"] = party_email(conn, b["supplier"])
    b["consignee_email"] = party_email(conn, b["consignee"])
    b["supplier_phone"] = party_phone(conn, b["supplier"])
    b["consignee_phone"] = party_phone(conn, b["consignee"])
    b["supplier_addr"] = party_address_block(conn, b["supplier"], "Primary")
    if not b["supplier_addr"]:
        b["supplier_addr"] = party_address_block(conn, b["supplier"])
    b["bill_to_addr"] = party_address_block(conn, b["consignee"], "Billing")
    if not b["bill_to_addr"]:
        b["bill_to_addr"] = party_address_block(conn, b["consignee"], "Primary")
    if not b["bill_to_addr"]:
        b["bill_to_addr"] = party_address_block(conn, b["consignee"])
    b["ship_to_addr"] = party_address_block(conn, b["consignee"], "Shipping")
    if not b["ship_to_addr"]:
        b["ship_to_addr"] = b["bill_to_addr"]

    b["refs"] = bill_references(conn, bill_id)
    return b


def build_pdf(data: dict, out_path: Path) -> None:
    styles = getSampleStyleSheet()
    style_company = ParagraphStyle(
        "Company",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=16,
        leading=20,  # room under bold name so it does not collide with address
        textColor=QB_DARK,
        spaceAfter=8,
    )
    style_small = ParagraphStyle(
        "Small",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        textColor=QB_GRAY,
        leading=12,
        spaceBefore=0,
        spaceAfter=2,
    )
    style_label = ParagraphStyle(
        "Label",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8,
        textColor=QB_GRAY,
        spaceBefore=6,
        spaceAfter=2,
    )
    style_body = ParagraphStyle(
        "Body9",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        textColor=QB_DARK,
        leading=12,
    )
    style_inv_title = ParagraphStyle(
        "InvTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=22,
        leading=28,  # large title needs own line height
        textColor=QB_GREEN,
        alignment=2,  # right
        spaceAfter=10,  # clear gap before "Invoice #"
    )
    style_meta = ParagraphStyle(
        "Meta",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        textColor=QB_DARK,
        alignment=2,
        leading=13,
        spaceBefore=1,
        spaceAfter=2,
    )
    style_th = ParagraphStyle(
        "TH",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8,
        textColor=QB_DARK,
    )
    style_td = ParagraphStyle(
        "TD",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9,
        textColor=QB_DARK,
    )
    style_td_r = ParagraphStyle(
        "TDR",
        parent=style_td,
        alignment=2,
    )
    style_thanks = ParagraphStyle(
        "Thanks",
        parent=styles["Normal"],
        fontName="Helvetica-Oblique",
        fontSize=9,
        textColor=QB_GRAY,
    )

    inv_no = data.get("invoice_number") or f"INV-{data['bill']:05d}"
    inv_date = data["date"] or datetime.now().strftime("%Y-%m-%d")
    try:
        d0 = datetime.strptime(str(inv_date)[:10], "%Y-%m-%d")
        due = (d0 + timedelta(days=30)).strftime("%Y-%m-%d")
    except ValueError:
        due = ""

    doc = SimpleDocTemplate(
        str(out_path),
        pagesize=letter,
        leftMargin=0.65 * inch,
        rightMargin=0.65 * inch,
        topMargin=0.55 * inch,
        bottomMargin=0.6 * inch,
        title=f"Invoice {inv_no}",
        author=data["supplier_display"],
    )

    story = []

    # --- Header: company | INVOICE ---
    company_lines = [Paragraph(data["supplier_display"], style_company)]
    for line in data["supplier_addr"]:
        company_lines.append(Paragraph(line, style_small))
    if data["supplier_phone"]:
        company_lines.append(Paragraph(data["supplier_phone"], style_small))
    if data["supplier_email"]:
        company_lines.append(Paragraph(data["supplier_email"], style_small))

    right_block = [
        Paragraph("INVOICE", style_inv_title),
        # Extra air under green title (spaceAfter on style alone can still feel tight in tables)
        Spacer(1, 8),
        Paragraph(f"<b>Invoice #</b>&nbsp;&nbsp;{inv_no}", style_meta),
        Paragraph(f"<b>Date</b>&nbsp;&nbsp;{inv_date}", style_meta),
        Paragraph(f"<b>Due date</b>&nbsp;&nbsp;{due}", style_meta),
        Paragraph(f"<b>Terms</b>&nbsp;&nbsp;Net 30", style_meta),
    ]
    for rtype, rval in data["refs"]:
        right_block.append(Paragraph(f"<b>{rtype}</b>&nbsp;&nbsp;{rval}", style_meta))

    header = Table(
        [[company_lines, right_block]],
        colWidths=[4.2 * inch, 3.0 * inch],
    )
    header.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("RIGHTPADDING", (0, 0), (-1, -1), 0),
            ]
        )
    )
    story.append(header)
    story.append(Spacer(1, 8))
    story.append(HRFlowable(width="100%", thickness=2, color=QB_GREEN, spaceAfter=10))

    # Balance due callout (QB style)
    bal_tbl = Table(
        [
            [
                Paragraph("<b>BALANCE DUE</b>", style_th),
                Paragraph(f"<b>{money(data['balance_due'])}</b>", ParagraphStyle("Bal", parent=style_td_r, fontSize=12, textColor=QB_GREEN)),
            ]
        ],
        colWidths=[5.5 * inch, 1.7 * inch],
    )
    bal_tbl.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), QB_TOTAL_BG),
                ("BOX", (0, 0), (-1, -1), 0.5, QB_GREEN),
                ("LEFTPADDING", (0, 0), (-1, -1), 8),
                ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    story.append(bal_tbl)
    story.append(Spacer(1, 14))

    # Bill To / Ship To
    def addr_cell(title: str, name: str, lines: list[str], email: str, phone: str):
        parts = [Paragraph(title, style_label), Paragraph(f"<b>{name}</b>", style_body)]
        for ln in lines:
            parts.append(Paragraph(ln, style_body))
        if phone:
            parts.append(Paragraph(phone, style_body))
        if email:
            parts.append(Paragraph(email, style_body))
        return parts

    parties = Table(
        [
            [
                addr_cell("BILL TO", data["consignee_display"], data["bill_to_addr"], data["consignee_email"], data["consignee_phone"]),
                addr_cell("SHIP TO", data["consignee_display"], data["ship_to_addr"], "", ""),
            ]
        ],
        colWidths=[3.6 * inch, 3.6 * inch],
    )
    parties.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("BACKGROUND", (0, 0), (-1, -1), colors.white),
            ]
        )
    )
    story.append(parties)
    story.append(Spacer(1, 16))

    # Line items table
    header_row = [
        Paragraph("#", style_th),
        Paragraph("PRODUCT / SERVICE", style_th),
        Paragraph("DESCRIPTION", style_th),
        Paragraph("QTY", style_th),
        Paragraph("RATE", style_th),
        Paragraph("AMOUNT", style_th),
    ]
    table_data = [header_row]
    for i, ln in enumerate(data["lines"], start=1):
        desc = ln["version"] or ""
        item = ln["item"] or ""
        table_data.append(
            [
                Paragraph(str(i), style_td),
                Paragraph(str(item), style_td),
                Paragraph(str(desc), style_td),
                Paragraph(f"{float(ln['count']):g}", style_td_r),
                Paragraph(money(ln["unit"]), style_td_r),
                Paragraph(money(ln["total"] if ln["total"] is not None else (float(ln["unit"] or 0) * float(ln["count"] or 1))), style_td_r),
            ]
        )

    if len(table_data) == 1:
        table_data.append(
            [
                Paragraph("", style_td),
                Paragraph("(no line items)", style_td),
                Paragraph("", style_td),
                Paragraph("", style_td),
                Paragraph("", style_td),
                Paragraph("", style_td),
            ]
        )

    col_w = [0.35 * inch, 1.6 * inch, 2.4 * inch, 0.7 * inch, 0.9 * inch, 1.05 * inch]
    items = Table(table_data, colWidths=col_w, repeatRows=1)
    items.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), QB_HEADER_BG),
                ("LINEBELOW", (0, 0), (-1, 0), 1, QB_DARK),
                ("LINEBELOW", (0, 1), (-1, -1), 0.4, QB_LINE),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(items)
    story.append(Spacer(1, 12))

    # Totals
    tot_rows = [
        [Paragraph("Subtotal", style_td), Paragraph(money(data["subtotal"]), style_td_r)],
        [Paragraph("Tax", style_td), Paragraph(money(data["tax"]), style_td_r)],
        [Paragraph("<b>Total</b>", style_td), Paragraph(f"<b>{money(data['total'])}</b>", style_td_r)],
        [Paragraph("Amount paid", style_td), Paragraph(money(data["amount_paid"]), style_td_r)],
        [
            Paragraph("<b>Balance due</b>", ParagraphStyle("BD", parent=style_td, textColor=QB_GREEN)),
            Paragraph(f"<b>{money(data['balance_due'])}</b>", ParagraphStyle("BDR", parent=style_td_r, textColor=QB_GREEN)),
        ],
    ]
    totals = Table(tot_rows, colWidths=[1.4 * inch, 1.2 * inch], hAlign="RIGHT")
    totals.setStyle(
        TableStyle(
            [
                ("LINEABOVE", (0, 2), (-1, 2), 0.5, QB_LINE),
                ("LINEABOVE", (0, 4), (-1, 4), 1, QB_GREEN),
                ("BACKGROUND", (0, 4), (-1, 4), QB_TOTAL_BG),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )
    story.append(totals)
    story.append(Spacer(1, 28))
    story.append(Paragraph("Thank you for your business.", style_thanks))
    story.append(
        Paragraph(
            f"Document type in books: <b>{data['type']}</b> · Bill id {data['bill']}"
            + (f" · Parent {data['parentType']} #{data['parent']}" if data["parent"] else ""),
            style_small,
        )
    )

    doc.build(story)


def main() -> None:
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(1)
    bill_id = int(sys.argv[1])
    db = os.environ.get("SQLITE_DB", str(Path.home() / "business-shop" / "business.sqlite3"))
    if len(sys.argv) >= 3:
        out = Path(sys.argv[2]).expanduser()
    else:
        out_dir = Path.home() / "business-shop" / "invoices"
        out_dir.mkdir(parents=True, exist_ok=True)
        out = out_dir / f"invoice-{bill_id:05d}.pdf"

    conn = sqlite3.connect(db)
    try:
        data = load_invoice(conn, bill_id)
    finally:
        conn.close()

    out.parent.mkdir(parents=True, exist_ok=True)
    build_pdf(data, out)
    print(out)


if __name__ == "__main__":
    main()
