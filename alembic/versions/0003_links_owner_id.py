"""links.owner_id: per-user ownership

Revision ID: 0003
Revises: 0002
Create Date: 2026-06-03

Adds `owner_id` to `links` for Phase 1 ownership (ADR 0009). Every newly-minted
Link is stamped with its creator; the column is nullable so legacy pre-auth
Links stay ownerless and still redirect, but never surface in any dashboard
("start empty" — no backfill). A foreign key ties owned Links to `users.id`.
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("links", sa.Column("owner_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_links_owner_id_users",
        "links",
        "users",
        ["owner_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint("fk_links_owner_id_users", "links", type_="foreignkey")
    op.drop_column("links", "owner_id")
