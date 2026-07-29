#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
旧数据迁移脚本：从 pj_003（sqflite）导出数据到 CSV 文件。

用途：
  python scripts/migrate_from_old.py <旧数据库.db路径> [--output <输出目录>]

示例：
  python scripts/migrate_from_old.py "C:\\Users\\wanji\\account_book.db"
  python scripts/migrate_from_old.py account_book.db --output ./migration_output

输出：
  transactions.csv        — 交易记录（名称已解析，兼容 BeeCount 手动导入）
  accounts.csv             — 账户
  categories.csv           — 分类（含父分类名）
  investment_holdings.csv  — 投资持仓
  periodic_bills.csv       — 定期账单/周期交易
  books.csv                — 账本信息（参考用）
  README.md                — 迁移说明 + 字段映射文档
"""

import csv
import os
import sqlite3
import sys
from datetime import datetime
from pathlib import Path


def resolve_names(conn: sqlite3.Connection) -> dict:
    """将 UUID 外键解析为名称缓存，供导出时使用。"""
    names: dict[str, dict[str, str]] = {}

    # 账户：UUID → name
    names["accounts"] = {}
    for row in conn.execute("SELECT id, name FROM accounts"):
        names["accounts"][row[0]] = row[1]

    # 分类：UUID → name
    names["categories"] = {}
    for row in conn.execute("SELECT id, name FROM categories"):
        names["categories"][row[0]] = row[1]

    # 账本：UUID → name
    names["books"] = {}
    for row in conn.execute("SELECT id, name FROM books"):
        names["books"][row[0]] = row[1]

    return names


def table_exists(conn: sqlite3.Connection, table_name: str) -> bool:
    """检查表是否存在。"""
    cur = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        (table_name,),
    )
    return cur.fetchone() is not None


def export_books(conn: sqlite3.Connection, out_dir: Path) -> int:
    """导出账本信息。"""
    if not table_exists(conn, "books"):
        print("  [!] books 表不存在，跳过")
        return 0

    path = out_dir / "books.csv"
    rows = conn.execute("SELECT id, name, cover, created_at, updated_at FROM books").fetchall()
    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["id", "name", "cover", "created_at", "updated_at"])
        w.writerows(rows)
    print(f"  [v] books.csv — {len(rows)} 行")
    return len(rows)


def export_accounts(conn: sqlite3.Connection, out_dir: Path, names: dict) -> int:
    """导出账户，附加账本名。"""
    if not table_exists(conn, "accounts"):
        print("  [!] accounts 表不存在，跳过")
        return 0

    path = out_dir / "accounts.csv"
    rows = conn.execute(
        "SELECT id, book_id, name, type, balance, currency, status, "
        "billing_day, repayment_day, sort_order, created_at, updated_at "
        "FROM accounts ORDER BY sort_order, name"
    ).fetchall()

    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "id", "book_name", "name", "type", "balance", "currency", "status",
            "billing_day", "repayment_day", "sort_order", "created_at", "updated_at",
        ])
        for row in rows:
            book_name = names["books"].get(row[1], row[1])
            w.writerow([
                row[0], book_name, row[2], row[3], row[4], row[5], row[6],
                row[7], row[8], row[9], row[10], row[11],
            ])
    print(f"  [v] accounts.csv — {len(rows)} 行")
    return len(rows)


def export_categories(conn: sqlite3.Connection, out_dir: Path, names: dict) -> int:
    """导出分类，解析父分类名为可读字符串。"""
    if not table_exists(conn, "categories"):
        print("  [!] categories 表不存在，跳过")
        return 0

    path = out_dir / "categories.csv"
    rows = conn.execute(
        "SELECT id, book_id, name, type, parent_id, icon, sort_order, created_at "
        "FROM categories ORDER BY sort_order, name"
    ).fetchall()

    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "id", "book_name", "name", "type", "parent_name", "icon", "sort_order", "created_at",
        ])
        for row in rows:
            book_name = names["books"].get(row[1], row[1])
            parent_name = ""
            if row[4]:  # parent_id
                parent_name = names["categories"].get(row[4], row[4])
            w.writerow([
                row[0], book_name, row[2], row[3], parent_name, row[5], row[6], row[7],
            ])
    print(f"  [v] categories.csv — {len(rows)} 行")
    return len(rows)


def export_transactions(conn: sqlite3.Connection, out_dir: Path, names: dict) -> int:
    """导出交易记录，所有外键解析为可读名称。"""
    if not table_exists(conn, "transactions"):
        print("  [!] transactions 表不存在，跳过")
        return 0

    path = out_dir / "transactions.csv"
    columns = [
        "id", "book_id", "account_id", "to_account_id", "category_id",
        "type", "amount", "datetime", "note", "is_investment",
        "related_investment_id", "batch_id", "invest_type", "code",
        "invest_shares", "invest_nav", "invest_fee",
    ]
    # 先检测有哪些列（旧版本可能缺少 v7 迁移后的 invest_shares 等列）
    cursor = conn.execute("SELECT * FROM transactions LIMIT 0")
    available_cols = [desc[0] for desc in cursor.description]

    col_list = [c for c in columns if c in available_cols]
    rows = conn.execute(
        f"SELECT {', '.join(col_list)} FROM transactions ORDER BY datetime DESC"
    ).fetchall()

    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        # 输出列头（用解析后的名称）
        header = []
        for c in col_list:
            if c == "book_id":
                header.append("book_name")
            elif c == "account_id":
                header.append("account_name")
            elif c == "to_account_id":
                header.append("to_account_name")
            elif c == "category_id":
                header.append("category_name")
            elif c == "related_investment_id":
                header.append("related_investment_code")
            else:
                header.append(c)
        w.writerow(header)

        for row in rows:
            out = []
            for i, c in enumerate(col_list):
                val = row[i]
                if c == "book_id":
                    out.append(names["books"].get(val, val if val else ""))
                elif c == "account_id":
                    out.append(names["accounts"].get(val, val if val else ""))
                elif c == "to_account_id":
                    out.append(names["accounts"].get(val, val if val else "") if val else "")
                elif c == "category_id":
                    out.append(names["categories"].get(val, val if val else "") if val else "")
                elif c == "related_investment_id":
                    # related_investment_id 指向 holdings，尝试查持仓 code
                    if val:
                        h = conn.execute(
                            "SELECT code FROM investment_holdings WHERE id=?",
                            (val,),
                        ).fetchone()
                        out.append(h[0] if h else val)
                    else:
                        out.append("")
                else:
                    out.append(val if val is not None else "")
            w.writerow(out)
    print(f"  [v] transactions.csv — {len(rows)} 行")
    return len(rows)


def export_investment_holdings(conn: sqlite3.Connection, out_dir: Path, names: dict) -> int:
    """导出投资持仓，解析 account/book 外键。"""
    if not table_exists(conn, "investment_holdings"):
        print("  [!] investment_holdings 表不存在，跳过")
        return 0

    path = out_dir / "investment_holdings.csv"
    rows = conn.execute(
        "SELECT id, book_id, account_id, code, name, inv_type, "
        "total_cost, total_shares, latest_nav, nav_date, fee_type, "
        "is_liquidated, created_at, updated_at "
        "FROM investment_holdings ORDER BY is_liquidated, code"
    ).fetchall()

    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "id", "book_name", "account_name", "code", "name", "holding_type",
            "total_cost", "total_shares", "latest_nav", "nav_date", "fee_type",
            "is_liquidated", "created_at", "updated_at",
        ])
        for row in rows:
            w.writerow([
                row[0],
                names["books"].get(row[1], row[1]),
                names["accounts"].get(row[2], row[2]),
                row[3], row[4], row[5],
                row[6], row[7], row[8], row[9], row[10],
                row[11], row[12], row[13],
            ])
    print(f"  [v] investment_holdings.csv — {len(rows)} 行")
    return len(rows)


def export_periodic_bills(conn: sqlite3.Connection, out_dir: Path, names: dict) -> int:
    """导出定期账单/周期交易。"""
    if not table_exists(conn, "periodic_bills"):
        print("  [!] periodic_bills 表不存在，跳过")
        return 0

    path = out_dir / "periodic_bills.csv"
    rows = conn.execute(
        "SELECT id, book_id, name, type, amount, account_id, category_id, "
        "frequency, interval_days, start_date, end_date, next_run_date, "
        "enabled, created_at, updated_at "
        "FROM periodic_bills ORDER BY next_run_date"
    ).fetchall()

    with open(path, "w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow([
            "id", "book_name", "name", "type", "amount",
            "account_name", "category_name",
            "frequency", "interval_days",
            "start_date", "end_date", "next_run_date",
            "enabled", "created_at", "updated_at",
        ])
        for row in rows:
            w.writerow([
                row[0],
                names["books"].get(row[1], row[1]),
                row[2], row[3], row[4],
                names["accounts"].get(row[5], row[5]) if row[5] else "",
                names["categories"].get(row[6], row[6]) if row[6] else "",
                row[7], row[8],
                row[9], row[10], row[11],
                row[12], row[13], row[14],
            ])
    print(f"  [v] periodic_bills.csv — {len(rows)} 行")
    return len(rows)


def generate_readme(out_dir: Path, total_rows: int, db_path: str) -> None:
    """生成迁移说明 README。"""
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    readme = out_dir / "README.md"
    content = f"""# 旧数据迁移输出 · {now}

**来源数据库**：`{db_path}`
**总计导出行数**：{total_rows}

## 输出文件一览

| 文件 | 内容 | 用途 |
|---|---|---|
| `books.csv` | 账本信息 | 参考用，新 App 初始化后自动创建默认账本 |
| `accounts.csv` | 账户列表（含名称、类型、余额、信用卡信息） | 在新 App 中手动创建同名的账户，或参考此表核对 |
| `categories.csv` | 分类列表（含父分类名） | 在新 App 中按名称创建对应分类 |
| `transactions.csv` | 全部交易记录（外键已解析为名称） | 主要数据源 |
| `investment_holdings.csv` | 投资持仓 | 需在新 App 中手动重建持仓 |
| `periodic_bills.csv` | 定期账单 | 需在新 App 的"周期交易"页面重新创建 |

## 迁移步骤建议

### 1. 在新 App 中创建账本 + 账户
- 打开新 App，创建默认账本
- 根据 `accounts.csv` 中的信息，手动创建同名账户
  - 现金/储蓄卡/信用卡/投资账户等
  - 注意信用卡的账单日（billing_day）和还款日（repayment_day）

### 2. 创建分类
- 在新 App 中根据 `categories.csv` 创建对应分类
- 一级分类先创建，二级分类选好父分类

### 3. 导入交易
- 交易记录已导出为 `transactions.csv`，但 BeeCount 的 CSV 导入目前主要用于支付宝/微信账单格式
- 建议：
  - **方案 A**：利用 BeeCount 的「配置导出/导入」功能（设置 → 数据管理 → 配置导入导出）
    将 `transactions.csv` 格式化为 YAML 后导入
  - **方案 B**：待 App 增加通用 CSV 导入功能后直接导入
  - **方案 C**：手工方式 — 按账户/分类名称在新 App 中重新录入关键交易

### 4. 重建投资持仓
- 在新 App 的投资页，根据 `investment_holdings.csv` 逐条「初始持仓导入」
- 注意：需要先创建投资类型的账户

### 5. 重建周期交易
- 在新 App 的"周期交易"页面，根据 `periodic_bills.csv` 逐条重建

## 字段映射（旧 → 新）

### 旧 transactions 表 → 新 Transactions 表

| 旧字段 | 新字段 | 说明 |
|---|---|---|
| id (UUID) | id (INTEGER 自增) | 主键类型变化，无法直接迁移 |
| book_id → book_name | ledgerId | 通过账本名称关联 |
| account_id → account_name | accountId | 通过账户名称关联 |
| to_account_id → to_account_name | toAccountId | 通过账户名称关联 |
| category_id → category_name | categoryId | 通过分类名称关联 |
| type | type | 直接映射：expense/income/transfer/invest |
| amount | amount | 直接映射 |
| datetime | happenedAt | 直接映射（DateTime 格式） |
| note | note | 直接映射 |
| invest_type | investType | 直接映射：buy/sell/redeem/switch_out/switch_in |
| invest_shares | investShares | 直接映射 |
| invest_nav | investNav | 直接映射 |
| invest_fee | investFee | 直接映射 |
| batch_id | batchId | 直接映射 |
| is_investment | [ERR] | 已废弃，用 type='invest' 替代 |
| code | [ERR] | 通过 holdingId 关联持仓 |
| related_investment_id | holdingId | 需要转换为新 int ID |

### 旧 investment_holdings 表 → 新 InvestmentHoldings 表

| 旧字段 | 新字段 | 说明 |
|---|---|---|
| id (UUID) | id (INTEGER 自增) | 主键类型变化 |
| book_id → book_name | ledgerId | 通过账本名称关联 |
| account_id → account_name | accountId | 通过账户名称关联 |
| code | fundCode | 直接映射 |
| name | fundName | 直接映射 |
| inv_type | holdingType | fund/stock/etf |
| total_cost | totalCost | 成本基数 |
| total_shares | totalShares | 持有份额 |
| latest_nav | currentNav | 最新净值 |
| nav_date | [ERR] | 新表无此字段 |
| fee_type | [ERR] | 新表无此字段 |
| is_liquidated | [ERR] | 可用 total_shares=0 判断 |

### 旧 periodic_bills 表 → 新 RecurringTransactions 表

| 旧字段 | 新字段 | 说明 |
|---|---|---|
| id (UUID) | id (INTEGER 自增) | 主键类型变化 |
| book_id → book_name | ledgerId | 通过账本名称关联 |
| name | name | 直接映射 |
| type | type | expense/income/transfer |
| amount | amount | 直接映射 |
| account_id → account_name | accountId | 通过账户名称关联 |
| category_id → category_name | categoryId | 通过分类名称关联 |
| frequency | frequency | daily/weekly/monthly/yearly |
| start_date | startDate | 直接映射 |
| end_date | endDate | 直接映射 |
| next_run_date | nextRunDate | 直接映射 |
| enabled | enabled | 直接映射 |

---

*此文件由 `scripts/migrate_from_old.py` 自动生成*
"""
    with open(readme, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  [v] README.md — 迁移说明文档")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    db_path = sys.argv[1]
    if not os.path.isfile(db_path):
        print(f"[ERR] 错误：找不到数据库文件 '{db_path}'")
        sys.exit(1)

    # 解析 --output 参数
    out_dir = Path("./migration_output")
    i = 2
    while i < len(sys.argv):
        if sys.argv[i] == "--output" and i + 1 < len(sys.argv):
            out_dir = Path(sys.argv[i + 1])
            i += 2
        else:
            i += 1

    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"[SRC] 源数据库: {db_path}")
    print(f"[OUT] 输出目录: {out_dir.resolve()}")
    print()

    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row

    try:
        print("[INFO] 解析外键名称…")
        names = resolve_names(conn)

        print("\n[EXP] 开始导出…")
        total = 0
        total += export_books(conn, out_dir)
        total += export_accounts(conn, out_dir, names)
        total += export_categories(conn, out_dir, names)
        total += export_transactions(conn, out_dir, names)
        total += export_investment_holdings(conn, out_dir, names)
        total += export_periodic_bills(conn, out_dir, names)

        generate_readme(out_dir, total, db_path)

        print(f"\n[OK] 迁移导出完成！共 {total} 条记录")
        print(f"   输出文件在: {out_dir.resolve()}")
        print(f"   请先阅读 README.md 了解字段映射和迁移步骤。")
    finally:
        conn.close()


if __name__ == "__main__":
    main()

