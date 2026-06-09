import httpx
import pytest

from app.services.spotify import (
    SpotifyClient,
    SpotifyError,
    SpotifyRateLimited,
    SpotifyResult,
)

TOKEN_PAYLOAD = {
    "access_token": "T1",
    "expires_in": 3600,
    "token_type": "Bearer",
}

TRACK_PAYLOAD = {
    "tracks": {
        "items": [
            {
                "uri": "spotify:track:abc",
                "name": "Blinding Lights",
                "duration_ms": 200040,
                "artists": [{"name": "The Weeknd"}],
                "album": {
                    "name": "After Hours",
                    "images": [{"url": "https://i.scdn.co/cover.jpg"}],
                },
                "external_urls": {"spotify": "https://open.spotify.com/track/abc"},
            }
        ]
    }
}

ALBUM_PAYLOAD = {
    "albums": {
        "items": [
            {
                "uri": "spotify:album:xyz",
                "name": "After Hours",
                "artists": [{"name": "The Weeknd"}],
                "images": [{"url": "https://i.scdn.co/album.jpg"}],
                "external_urls": {"spotify": "https://open.spotify.com/album/xyz"},
            }
        ]
    }
}

PLAYLIST_PAYLOAD = {
    "playlists": {
        "items": [
            {
                "uri": "spotify:playlist:pl1",
                "name": "Today's Top Hits",
                "owner": {"display_name": "Spotify"},
                "images": [{"url": "https://i.scdn.co/pl.jpg"}],
                "external_urls": {"spotify": "https://open.spotify.com/playlist/pl1"},
            }
        ]
    }
}


def make_mock(*, search_response: httpx.Response):
    """Returns (transport, counts, last_search_url)."""
    state = {"token": 0, "search": 0, "last": None}

    def handler(request: httpx.Request) -> httpx.Response:
        url = str(request.url)
        if "accounts.spotify.com/api/token" in url:
            state["token"] += 1
            return httpx.Response(200, json=TOKEN_PAYLOAD)
        if "api.spotify.com/v1/search" in url:
            state["search"] += 1
            state["last"] = request.url
            return search_response
        raise AssertionError(f"unexpected request: {url}")

    return httpx.MockTransport(handler), state


async def test_search_tracks_returns_typed_results():
    transport, state = make_mock(search_response=httpx.Response(200, json=TRACK_PAYLOAD))
    client = SpotifyClient("cid", "csecret", transport=transport)
    results = await client.search_tracks("blinding lights")
    assert len(results) == 1
    r = results[0]
    assert isinstance(r, SpotifyResult)
    assert r.spotify_uri == "spotify:track:abc"
    assert r.title == "Blinding Lights"
    assert r.artist == "The Weeknd"
    assert r.album == "After Hours"
    assert r.duration_ms == 200040
    assert r.cover_url == "https://i.scdn.co/cover.jpg"
    assert r.spotify_url == "https://open.spotify.com/track/abc"


async def test_search_albums_returns_typed_results():
    transport, _ = make_mock(search_response=httpx.Response(200, json=ALBUM_PAYLOAD))
    client = SpotifyClient("cid", "csecret", transport=transport)
    results = await client.search_albums("after hours")
    r = results[0]
    assert r.spotify_uri == "spotify:album:xyz"
    assert r.title == "After Hours"
    assert r.artist == "The Weeknd"
    assert r.album is None
    assert r.duration_ms is None
    assert r.cover_url == "https://i.scdn.co/album.jpg"


async def test_search_playlists_returns_typed_results():
    transport, _ = make_mock(search_response=httpx.Response(200, json=PLAYLIST_PAYLOAD))
    client = SpotifyClient("cid", "csecret", transport=transport)
    results = await client.search_playlists("top hits")
    r = results[0]
    assert r.spotify_uri == "spotify:playlist:pl1"
    assert r.title == "Today's Top Hits"
    assert r.artist == "Spotify"
    assert r.album is None
    assert r.duration_ms is None


async def test_token_cached_across_requests():
    transport, state = make_mock(search_response=httpx.Response(200, json=TRACK_PAYLOAD))
    client = SpotifyClient("cid", "csecret", transport=transport)
    await client.search_tracks("x")
    await client.search_tracks("y")
    assert state["token"] == 1
    assert state["search"] == 2


async def test_token_refreshed_when_expired():
    transport, state = make_mock(search_response=httpx.Response(200, json=TRACK_PAYLOAD))
    client = SpotifyClient("cid", "csecret", transport=transport)
    await client.search_tracks("x")
    client._expires_at = 0.0  # force expiry
    await client.search_tracks("y")
    assert state["token"] == 2


async def test_rate_limit_raises_typed_exception():
    transport, _ = make_mock(
        search_response=httpx.Response(429, headers={"Retry-After": "5"}, json={})
    )
    client = SpotifyClient("cid", "csecret", transport=transport)
    with pytest.raises(SpotifyRateLimited) as exc:
        await client.search_tracks("x")
    assert exc.value.retry_after == 5


async def test_server_error_raises_spotify_error():
    transport, _ = make_mock(search_response=httpx.Response(500, text="oops"))
    client = SpotifyClient("cid", "csecret", transport=transport)
    with pytest.raises(SpotifyError):
        await client.search_tracks("x")


async def test_null_playlist_items_are_filtered():
    payload = {
        "playlists": {
            "items": [
                None,
                PLAYLIST_PAYLOAD["playlists"]["items"][0],
            ]
        }
    }
    transport, _ = make_mock(search_response=httpx.Response(200, json=payload))
    client = SpotifyClient("cid", "csecret", transport=transport)
    results = await client.search_playlists("x")
    assert len(results) == 1
    assert results[0].spotify_uri == "spotify:playlist:pl1"


async def test_search_query_params_propagate():
    transport, state = make_mock(search_response=httpx.Response(200, json=TRACK_PAYLOAD))
    client = SpotifyClient("cid", "csecret", transport=transport)
    await client.search_tracks("blinding lights", limit=7)
    last = state["last"]
    assert last.params["q"] == "blinding lights"
    assert last.params["type"] == "track"
    assert last.params["limit"] == "7"


async def test_authorization_header_uses_bearer_token():
    captured: dict[str, httpx.Request] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        url = str(request.url)
        if "/api/token" in url:
            return httpx.Response(200, json=TOKEN_PAYLOAD)
        if "/v1/search" in url:
            captured["search"] = request
            return httpx.Response(200, json=TRACK_PAYLOAD)
        raise AssertionError(url)

    client = SpotifyClient("cid", "csecret", transport=httpx.MockTransport(handler))
    await client.search_tracks("x")
    assert captured["search"].headers["authorization"] == "Bearer T1"
