import logging
from typing import Any, Protocol

import httpx

from app.services.recommenders.base import RecommendedTrack, SeedTrack
from app.services.recommenders.yt_resolver import YTMusicResolver, YTResolver

logger = logging.getLogger(__name__)


class _ListenBrainzClient(Protocol):
    async def validate_token(self) -> str | None:
        """Returns the user_name bound to the token, or None if invalid."""
        ...

    async def get_user_recommendations(
        self, username: str, count: int
    ) -> list[dict]:
        """Returns `[{recording_mbid, score}, ...]` from the CF endpoint."""
        ...

    async def get_recording_metadata(
        self, mbids: list[str]
    ) -> dict[str, dict]:
        """Returns `{mbid: {recording: {name}, artist: {name}}, ...}`."""
        ...


class ListenBrainzHTTPClient:
    """Async wrapper around the ListenBrainz REST API.

    Production implementation. Tests should inject a fake conforming to the
    `_ListenBrainzClient` protocol — wire-format coverage is intentionally
    light here.
    """

    _BASE = "https://api.listenbrainz.org"

    def __init__(self, token: str, http: httpx.AsyncClient | None = None) -> None:
        self._token = token
        self._http = http if http is not None else httpx.AsyncClient(timeout=10.0)

    def _auth_headers(self) -> dict[str, str]:
        return {"Authorization": f"Token {self._token}"}

    async def validate_token(self) -> str | None:
        r = await self._http.get(
            f"{self._BASE}/1/validate-token", headers=self._auth_headers()
        )
        r.raise_for_status()
        data: dict[str, Any] = r.json()
        if data.get("valid") and isinstance(data.get("user_name"), str):
            return data["user_name"]
        return None

    async def get_user_recommendations(
        self, username: str, count: int
    ) -> list[dict]:
        r = await self._http.get(
            f"{self._BASE}/1/cf/recommendation/user/{username}/recording",
            params={"count": count},
        )
        r.raise_for_status()
        data: dict[str, Any] = r.json()
        payload = data.get("payload") or {}
        return payload.get("mbids") or []

    async def get_recording_metadata(
        self, mbids: list[str]
    ) -> dict[str, dict]:
        if not mbids:
            return {}
        r = await self._http.get(
            f"{self._BASE}/1/metadata/recording",
            params={"recording_mbids": ",".join(mbids), "inc": "artist"},
        )
        r.raise_for_status()
        data: dict[str, dict] = r.json() or {}
        return data


class ListenBrainzEngine:
    """Recommendation engine backed by ListenBrainz's collaborative-filter
    recommendations endpoint.

    Workflow:
      1. Resolve the username via `validate-token` (cached after first hit).
      2. Fetch `/1/cf/recommendation/user/<username>/recording?count=<limit>`
         — returns `recording_mbid` + `score` pairs sourced from MusicBrainz.
      3. Bulk-resolve mbids to (artist, title) via `/1/metadata/recording`.
      4. Resolve each (artist, title) to a `music.youtube.com` URL via the
         injected `YTResolver` so downloads flow through the existing pipeline.
      5. Drop unresolvable candidates; cap at `limit`.

    Per the I5 roadmap: client-side seeds are accepted but ignored — the user's
    ListenBrainz listening history drives results independently. Practical
    utility requires ≥ 1 week of scrobble history (see Android N1 milestone).
    """

    name = "listenbrainz"

    def __init__(
        self,
        token: str,
        client: _ListenBrainzClient | None = None,
        resolver: YTResolver | None = None,
    ) -> None:
        if not token:
            raise RuntimeError(
                "ListenBrainzEngine requires LISTENBRAINZ_USER_TOKEN"
            )
        self._client: _ListenBrainzClient = (
            client if client is not None else ListenBrainzHTTPClient(token)
        )
        self._resolver: YTResolver = (
            resolver if resolver is not None else YTMusicResolver()
        )
        self._username_cache: str | None = None

    async def _resolve_username(self) -> str | None:
        if self._username_cache is not None:
            return self._username_cache
        try:
            self._username_cache = await self._client.validate_token()
        except Exception as exc:
            logger.warning("listenbrainz validate-token failed: %s", exc)
            return None
        return self._username_cache

    async def recommend(
        self, seeds: list[SeedTrack], limit: int
    ) -> list[RecommendedTrack]:
        username = await self._resolve_username()
        if not username:
            return []

        try:
            mbid_items = await self._client.get_user_recommendations(
                username, limit
            )
        except Exception as exc:
            logger.warning("listenbrainz recommendations failed: %s", exc)
            return []
        if not mbid_items:
            return []

        mbids: list[str] = []
        for item in mbid_items:
            mbid = item.get("recording_mbid")
            if isinstance(mbid, str) and mbid:
                mbids.append(mbid)
        if not mbids:
            return []

        try:
            metadata = await self._client.get_recording_metadata(mbids)
        except Exception as exc:
            logger.warning("listenbrainz metadata failed: %s", exc)
            return []

        out: list[RecommendedTrack] = []
        for item in mbid_items:
            if len(out) >= limit:
                break
            mbid = item.get("recording_mbid")
            if not isinstance(mbid, str) or not mbid:
                continue
            meta = metadata.get(mbid) or {}
            recording = meta.get("recording") or {}
            artist_block = meta.get("artist") or {}
            title = recording.get("name") or ""
            artist = (
                artist_block.get("name", "")
                if isinstance(artist_block, dict)
                else ""
            )
            if not title or not artist:
                continue

            url = await self._resolver.resolve(artist, title)
            if url is None:
                continue

            raw_score = item.get("score")
            try:
                score: float | None = (
                    float(raw_score) if raw_score is not None else None
                )
            except (TypeError, ValueError):
                score = None

            out.append(
                RecommendedTrack(
                    title=title,
                    artist=artist,
                    source_url=url,
                    score=score,
                )
            )
        return out

    async def probe(self) -> bool:
        try:
            username = await self._client.validate_token()
        except Exception as exc:
            logger.warning("listenbrainz probe failed: %s", exc)
            return False
        return bool(username)

    async def health_chain(self) -> list[tuple[str, bool]]:
        return [(self.name, await self.probe())]
