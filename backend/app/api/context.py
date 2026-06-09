from contextvars import ContextVar

# Per-request context. Populated by middleware (request_id) and the auth
# dependency (owner_label). Read by the logging filter so every log record
# emitted during a request carries these fields without callers passing them.
#
# Defaults are sentinels rather than None so JSON logs always have the keys.
request_id_var: ContextVar[str] = ContextVar("request_id", default="-")
owner_label_var: ContextVar[str] = ContextVar("owner_label", default="-")
