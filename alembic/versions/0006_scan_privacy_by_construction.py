"""scan_privacy_by_construction: drop ip_address/user_agent, add country/subdivision/device_class

Revision ID: 0006
Revises: 0005
Create Date: 2026-06-12

Implements ADR 0016 privacy-by-construction scan model.

Drops the raw ``ip_address`` and ``user_agent`` columns (which leaked scanner
identity in violation of ADR 0006) and replaces them with coarse derived
attributes: ``country``, ``subdivision``, and ``device_class``.

All three are nullable — existing rows carry NULLs (no backfill; the data is
prototype-only, consistent with the Phase 2 "no data migration" stance).

This migration makes the ADR 0006 privacy guarantee structurally true: you
cannot leak what you never persisted.
"""
from __future__ import annotations

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Drop the raw privacy-leaking columns (ADR 0006 / ADR 0016).
    op.drop_column("scans", "ip_address")
    op.drop_column("scans", "user_agent")

    # Add coarse derived attributes (nullable; no backfill for existing rows).
    op.add_column(
        "scans",
        sa.Column("country", sa.String(2), nullable=True),
    )
    op.add_column(
        "scans",
        sa.Column("subdivision", sa.String(6), nullable=True),
    )
    op.add_column(
        "scans",
        sa.Column("device_class", sa.String(10), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("scans", "device_class")
    op.drop_column("scans", "subdivision")
    op.drop_column("scans", "country")

    op.add_column("scans", sa.Column("user_agent", sa.String(), nullable=True))
    op.add_column("scans", sa.Column("ip_address", sa.String(), nullable=True))
