import uuid

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.api.v1.router import api_v1
from app.db import get_session
from app.models import Download, Job
from app.services.spotify import (
    SpotifyRateLimited,
    SpotifyResult,
    get_spotify_client,
)


def _track(uri: str, title: str = "x", artist: str = "y") -> SpotifyResult:
    return SpotifyResult(
        spotify_uri=uri,
        spotify_url=f"https://open.spotify.com/{uri}",
        title=title,
        artist=artist,
        album="A",
        duration_ms=1000,
        cover_url="https://i.scdn.co/cover.jpg",
    )


def _album(uri: str) -> SpotifyResult:
    return SpotifyResult(
        spotify_uri=uri,
        spotify_url=f"https://open.spotify.com/{uri}",
        title="alb",
        artist="art",
        album=None,
        duration_ms=None,
        cover_url=None,
    )


def _playlist(uri: str) -> SpotifyResult:
    return SpotifyResult(
        spotify_uri=uri,
        spotify_url=f"https://open.spotify.com/{uri}",
        title="pl",
        artist="owner",
        album=None,
        duration_ms=None,
        cover_url=None,
    )


class FakeSpotify:
    def __init__(self):
        self.tracks: list[SpotifyResult] = []
        self.albums: list[SpotifyResult] = []
        self.playlists: list[SpotifyResult] = []
        self.raise_rate_limit_after: int | None = None  # retry seconds
        self.last_query: str | None = None
        self.last_limit: int | None = None

    async def search_tracks(self, q, limit=20):
        self.last_query = q
        self.last_limit = limit
        if self.raise_rate_limit_after is not None:
            raise SpotifyRateLimited(self.raise_rate_limit_after)
        return list(self.tracks)

    async def search_albums(self, q, limit=20):
        self.last_query = q
        self.last_limit = limit
        return list(self.albums)

    async def search_playlists(self, q, limit=20):
        self.last_query = q
        self.last_limit = limit
        return list(self.playlists)


@pytest.fixture
async def fake_spotify():
    return FakeSpotify()


@pytest.fixture
async def search_app(app_sm, fake_spotify):
    app = FastAPI()

    async def override_get_session():
        async with app_sm() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise

    app.dependency_overrides[get_session] = override_get_session
    app.dependency_overrides[get_spotify_client] = lambda: fake_spotify
    app.include_router(api_v1)
    yield app


@pytest.fixture
async def client(search_app):
    transport = ASGITransport(app=search_app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


@pytest.fixture
async def cleanup(app_sm):
    """Tear down jobs+downloads inserted during the test (FK order matters)."""
    yield
    async with app_sm() as s:
        await s.execute(text("DELETE FROM downloads"))
        await s.execute(text("DELETE FROM jobs"))
        await s.commit()


async def _seed_download(app_sm, token_id, spotify_uri: str):
    """Insert a job-then-download pair so the downloads row has its FK."""
    job_id = uuid.uuid4()
    async with app_sm() as s:
        s.add(
            Job(
                id=job_id,
                spotify_uri=spotify_uri,
                spotify_type="track",
                state="done",
                created_by_token_id=token_id,
            )
        )
        await s.flush()
        s.add(
            Download(
                spotify_track_uri=spotify_uri,
                job_id=job_id,
                output_path=f"/data/media/music/{spotify_uri}.mp3",
            )
        )
        await s.commit()


async def _seed_active_job(app_sm, token_id, spotify_uri: str, type_: str, state: str = "queued"):
    job_id = uuid.uuid4()
    async with app_sm() as s:
        s.add(
            Job(
                id=job_id,
                spotify_uri=spotify_uri,
                spotify_type=type_,
                state=state,
                created_by_token_id=token_id,
            )
        )
        await s.commit()
    return job_id


async def _token_id_for(app_sm, raw: str):
    import hashlib

    h = hashlib.sha256(raw.encode()).hexdigest()
    async with app_sm() as s:
        r = await s.execute(text("SELECT id FROM tokens WHERE token_hash = :h"), {"h": h})
        return r.scalar_one()


# ---- auth / scope branches ------------------------------------------------


async def test_search_requires_auth(client):
    r = await client.post("/api/v1/search", json={"query": "x", "type": "track"})
    assert r.status_code == 401


async def test_search_requires_read_scope(client, make_token):
    raw = await make_token(scopes=("download",))
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "track"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 403


# ---- request validation ---------------------------------------------------


async def test_invalid_type_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "podcast"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_limit_out_of_range_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "track", "limit": 999},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_empty_query_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/search",
        json={"query": "", "type": "track"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


async def test_unknown_field_returns_422(client, make_token):
    raw = await make_token()
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "track", "evil": True},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 422


# ---- contract shape -------------------------------------------------------


async def test_track_search_returns_contract_fields(client, make_token, fake_spotify, cleanup):
    raw = await make_token()
    fake_spotify.tracks = [_track("spotify:track:t1", title="Blinding Lights", artist="The Weeknd")]
    r = await client.post(
        "/api/v1/search",
        json={"query": "blinding lights", "type": "track"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["results"]) == 1
    item = body["results"][0]
    assert set(item.keys()) == {
        "spotify_uri",
        "spotify_url",
        "title",
        "artist",
        "album",
        "duration_ms",
        "cover_url",
        "already_downloaded",
        "active_job_id",
    }
    assert item["title"] == "Blinding Lights"
    assert item["already_downloaded"] is False
    assert item["active_job_id"] is None


# ---- dedup hints ----------------------------------------------------------


async def test_track_already_downloaded_hint(client, make_token, fake_spotify, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    uri = "spotify:track:dl-1"
    await _seed_download(app_sm, token_id, uri)
    fake_spotify.tracks = [
        _track(uri),
        _track("spotify:track:other"),
    ]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "track"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    by_uri = {it["spotify_uri"]: it for it in r.json()["results"]}
    assert by_uri[uri]["already_downloaded"] is True
    assert by_uri["spotify:track:other"]["already_downloaded"] is False


async def test_track_active_job_hint(client, make_token, fake_spotify, app_sm, cleanup):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    uri = "spotify:track:queued-1"
    job_id = await _seed_active_job(app_sm, token_id, uri, "track", "queued")
    fake_spotify.tracks = [_track(uri)]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "track"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    item = r.json()["results"][0]
    assert item["active_job_id"] == str(job_id)
    assert item["already_downloaded"] is False  # not in downloads


async def test_done_job_does_not_populate_active_job_id(
    client, make_token, fake_spotify, app_sm, cleanup
):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    uri = "spotify:track:done-1"
    # Seed a done job (and a download — to be a realistic post-completion state)
    await _seed_download(app_sm, token_id, uri)
    fake_spotify.tracks = [_track(uri)]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "track"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    item = r.json()["results"][0]
    assert item["active_job_id"] is None
    assert item["already_downloaded"] is True


async def test_album_active_job_hint_but_no_download(
    client, make_token, fake_spotify, app_sm, cleanup
):
    raw = await make_token()
    token_id = await _token_id_for(app_sm, raw)
    uri = "spotify:album:queued-1"
    job_id = await _seed_active_job(app_sm, token_id, uri, "album", "running")
    fake_spotify.albums = [_album(uri)]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "album"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    item = r.json()["results"][0]
    assert item["active_job_id"] == str(job_id)
    assert item["already_downloaded"] is False  # downloads is track-only
    assert item["album"] is None
    assert item["duration_ms"] is None


async def test_playlist_search_returns_results(client, make_token, fake_spotify, cleanup):
    raw = await make_token()
    fake_spotify.playlists = [_playlist("spotify:playlist:p1")]
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "playlist"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 200
    assert r.json()["results"][0]["spotify_uri"] == "spotify:playlist:p1"


# ---- rate limit translation ----------------------------------------------


async def test_spotify_rate_limit_translates_to_503(client, make_token, fake_spotify):
    raw = await make_token()
    fake_spotify.raise_rate_limit_after = 7
    r = await client.post(
        "/api/v1/search",
        json={"query": "x", "type": "track"},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert r.status_code == 503
    assert r.headers.get("retry-after") == "7"


# ---- query plumbing -------------------------------------------------------


async def test_query_and_limit_passed_to_spotify(client, make_token, fake_spotify):
    raw = await make_token()
    fake_spotify.tracks = []
    await client.post(
        "/api/v1/search",
        json={"query": "blinding lights", "type": "track", "limit": 5},
        headers={"Authorization": f"Bearer {raw}"},
    )
    assert fake_spotify.last_query == "blinding lights"
    assert fake_spotify.last_limit == 5
