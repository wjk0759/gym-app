#!/usr/bin/env python3
"""Copy FitAI's SQLite development data into the MySQL schema.

The MySQL schema itself is owned by admin-server Flyway migrations. Run the
admin service once (or `mvn flyway:migrate`) so V1/V2 exist, then:

    python tools/db/migrate_sqlite_to_mysql.py --source backend/fitai.db \
        --target mysql+pymysql://fitai:fitai@127.0.0.1:3306/fitai?charset=utf8mb4 \
        --replace

This is an explicit, one-way data migration, not a runtime synchronization.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import date, datetime
from pathlib import Path
from typing import Any

from sqlalchemy import JSON, Boolean, Date, DateTime, Table, create_engine, inspect, text
from sqlalchemy.engine import Connection, Engine

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backend"))

from app.db import Base  # noqa: E402
import app.models  # noqa: E402,F401


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=str(ROOT / "backend" / "fitai.db"), help="SQLite database path")
    parser.add_argument("--target", default=os.getenv("FITAI_MYSQL_URL", ""), help="SQLAlchemy MySQL URL")
    parser.add_argument("--replace", action="store_true", help="Truncate existing app tables before import")
    parser.add_argument("--dry-run", action="store_true", help="Validate and report counts without writing")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_path = Path(args.source).resolve()
    if not source_path.exists():
        print(f"source SQLite DB not found: {source_path}", file=sys.stderr)
        return 2
    if not args.target:
        print("target MySQL URL is required (--target or FITAI_MYSQL_URL)", file=sys.stderr)
        return 2

    source = create_engine(f"sqlite:///{source_path.as_posix()}", future=True)
    target = create_engine(args.target, future=True, pool_pre_ping=True)
    tables = list(Base.metadata.sorted_tables)

    target_tables = set(inspect(target).get_table_names())
    missing = [table.name for table in tables if table.name not in target_tables]
    if missing:
        print("target schema is missing tables; run admin-server Flyway first: " + ", ".join(missing), file=sys.stderr)
        return 3

    with source.connect() as source_conn:
        source_tables = set(inspect(source).get_table_names())
        planned: list[tuple[Table, int]] = []
        for table in tables:
            if table.name not in source_tables:
                continue
            count = source_conn.execute(text(f"SELECT COUNT(*) FROM {table.name}")).scalar_one()
            planned.append((table, int(count)))
        if not planned:
            print("no app tables found in source", file=sys.stderr)
            return 4

        print("source:", source_path)
        print("target:", safe_target(args.target))
        for table, count in planned:
            print(f"  {table.name:32} {count:8} rows")
        if args.dry_run:
            print("dry run only; no writes performed")
            return 0

        with target.begin() as target_conn:
            target_conn.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
            try:
                if args.replace:
                    for table in reversed(tables):
                        target_conn.execute(text(f"TRUNCATE TABLE {table.name}"))
                else:
                    non_empty = [
                        table.name
                        for table in tables
                        if target_conn.execute(text(f"SELECT COUNT(*) FROM {table.name}")).scalar_one()
                    ]
                    if non_empty:
                        print("target contains data; use --replace or empty the database: " + ", ".join(non_empty),
                              file=sys.stderr)
                        return 5

                for table, _ in planned:
                    copy_table(source_conn, target_conn, table)
            finally:
                target_conn.execute(text("SET FOREIGN_KEY_CHECKS = 1"))

    with target.connect() as target_conn:
        print("verification:")
        for table in tables:
            source_count = 0
            if table.name in source_tables:
                with source.connect() as check_source:
                    source_count = int(check_source.execute(text(f"SELECT COUNT(*) FROM {table.name}")).scalar_one())
            target_count = int(target_conn.execute(text(f"SELECT COUNT(*) FROM {table.name}")).scalar_one())
            status = "OK" if source_count == target_count else "MISMATCH"
            print(f"  {table.name:32} source={source_count:8} target={target_count:8} {status}")
    return 0


def copy_table(source_conn: Connection, target_conn: Connection, table: Table) -> None:
    source_columns = {
        column["name"] for column in inspect(source_conn).get_columns(table.name)
    }
    columns = [column for column in table.columns if column.name in source_columns]
    if not columns:
        return
    select_sql = "SELECT " + ", ".join(f'"{column.name}"' for column in columns) + f' FROM "{table.name}"'
    rows = source_conn.execute(text(select_sql)).mappings().all()
    if not rows:
        return
    payload = []
    for row in rows:
        payload.append({column.name: convert(column, row[column.name]) for column in columns})
    target_conn.execute(table.insert(), payload)
    print(f"  copied {table.name}: {len(payload)} rows")


def convert(column, value: Any) -> Any:
    if value is None:
        return None
    column_type = column.type
    if isinstance(column_type, JSON):
        if isinstance(value, (dict, list)):
            return value
        if isinstance(value, bytes):
            value = value.decode("utf-8")
        if isinstance(value, str):
            if not value.strip():
                return None
            try:
                return json.loads(value)
            except json.JSONDecodeError:
                return value
        return value
    if isinstance(column_type, DateTime) and isinstance(value, str):
        return parse_datetime(value)
    if isinstance(column_type, Date) and isinstance(value, str):
        return parse_date(value)
    if isinstance(column_type, Boolean) and isinstance(value, str):
        return value.lower() in {"1", "true", "yes"}
    return value


def parse_datetime(value: str) -> datetime:
    normalized = value.strip().replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(normalized)
    except ValueError:
        return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")


def parse_date(value: str) -> date:
    return date.fromisoformat(value[:10])


def safe_target(url: str) -> str:
    if "@" not in url:
        return url
    prefix, suffix = url.split("@", 1)
    return prefix.split("//")[0] + "//***@" + suffix


if __name__ == "__main__":
    raise SystemExit(main())
