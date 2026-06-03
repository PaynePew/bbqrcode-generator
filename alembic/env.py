import os
from logging.config import fileConfig

from sqlalchemy import engine_from_config, pool

from alembic import context

# Load Alembic config
config = context.config

# Only configure logging from the ini file when running from the CLI.
# When invoked programmatically (e.g. from tests via alembic.command),
# the ini's fileConfig call would replace pytest's log-capture handlers,
# breaking caplog.  The caller is responsible for logging configuration.
if config.config_file_name is not None and not config.attributes.get("no_configure_logging"):
    fileConfig(config.config_file_name)

# Import the app's metadata so autogenerate can compare model vs DB.
from backend.models import Base  # noqa: E402

target_metadata = Base.metadata

# Allow DATABASE_URL environment variable to override alembic.ini.
# This lets CI and production pass the URL at runtime without editing the ini.
_url = os.environ.get("DATABASE_URL") or config.get_main_option("sqlalchemy.url")
config.set_main_option("sqlalchemy.url", _url)


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (emit SQL without connecting)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode (connect and apply)."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
