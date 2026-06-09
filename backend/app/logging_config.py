import json
import logging
from typing import Any

from app.api.context import owner_label_var, request_id_var


class _ContextFilter(logging.Filter):
    """Inject per-request ContextVars onto every LogRecord."""

    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = request_id_var.get()
        record.owner_label = owner_label_var.get()
        return True


# Keys that must never appear in a log payload — accidental leak of the raw
# bearer token or its sha256 hash would defeat the whole auth model.
_FORBIDDEN_KEYS = {"token", "token_hash", "credentials", "authorization"}

_STANDARD_LOGRECORD_ATTRS = {
    "name",
    "msg",
    "args",
    "levelname",
    "levelno",
    "pathname",
    "filename",
    "module",
    "exc_info",
    "exc_text",
    "stack_info",
    "lineno",
    "funcName",
    "created",
    "msecs",
    "relativeCreated",
    "thread",
    "threadName",
    "processName",
    "process",
    "message",
    "asctime",
    "request_id",
    "owner_label",
}


class JsonFormatter(logging.Formatter):
    """Minimal JSON formatter. Emits a single-line dict per record."""

    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S%z"),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
            "request_id": getattr(record, "request_id", "-"),
            "owner_label": getattr(record, "owner_label", "-"),
        }
        # Surface any caller-supplied `extra={...}` fields, skipping forbidden
        # keys and the stdlib LogRecord internals.
        for key, value in record.__dict__.items():
            if key in _STANDARD_LOGRECORD_ATTRS or key.startswith("_"):
                continue
            if key in _FORBIDDEN_KEYS:
                continue
            payload[key] = value
        if record.exc_info:
            payload["exc"] = self.formatException(record.exc_info)
        return json.dumps(payload, default=str)


def setup_logging(level: str = "INFO") -> None:
    """Install JSON formatter on the root logger; silence uvicorn.access.

    Called once at app startup. The middleware emits the per-request access
    line we actually want (with owner_label), so uvicorn's default access log
    is suppressed to avoid duplicate noise.
    """
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    handler.addFilter(_ContextFilter())

    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level)

    # Uvicorn ships its own loggers configured by its own dictConfig at boot.
    # Re-route them through our handler and silence the access log (our
    # middleware emits the access line that satisfies the CLAUDE.md mandate).
    for name in ("uvicorn", "uvicorn.error"):
        lg = logging.getLogger(name)
        lg.handlers.clear()
        lg.propagate = True
    logging.getLogger("uvicorn.access").disabled = True
