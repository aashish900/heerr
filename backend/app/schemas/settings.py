from pydantic import BaseModel, ConfigDict


class UserSettingsView(BaseModel):
    """Read shape for `GET/PATCH /settings`.

    The ListenBrainz token is a secret — it is never echoed back. The view
    surfaces only whether one is stored (`listenbrainz_token_set`).
    """

    lastfm_username: str | None = None
    listenbrainz_token_set: bool = False


class UserSettingsUpdate(BaseModel):
    """Write shape for `PATCH /settings`.

    Partial update: only fields present in the request body are applied. An
    explicit `null` (or empty string) clears the stored value.
    """

    model_config = ConfigDict(extra="forbid")

    lastfm_username: str | None = None
    listenbrainz_token: str | None = None
