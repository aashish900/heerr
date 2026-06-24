import pytest

from app.services.spotdl_runner import (
    AgeGatedError,
    DownloadedFile,
    NetworkError,
    RateLimitedError,
    RegionLockedError,
    SpotdlError,
    TranscodeError,
    UnknownSpotdlError,
    VideoUnavailableError,
    _classify_error,
    run_spotdl,
)


class FakeProc:
    def __init__(
        self,
        returncode: int,
        stdout: bytes = b"",
        stderr: bytes = b"",
    ):
        self.returncode = returncode
        # Simulate stderr=STDOUT merge: combined output lands in stdout
        self._combined = stdout + stderr

    async def communicate(self):
        return self._combined, None


# ---- happy path: produces new files --------------------------------------


async def test_happy_path_returns_new_files(tmp_path, monkeypatch):
    captured: dict[str, list[str]] = {}

    async def fake_spawn(cmd):
        captured["cmd"] = list(cmd)
        (tmp_path / "song.mp3").write_bytes(b"audio-bytes")
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    results = await run_spotdl("spotify:track:abc", tmp_path)
    assert len(results) == 1
    assert isinstance(results[0], DownloadedFile)
    assert results[0].path.endswith("song.mp3")
    assert results[0].size_bytes == len(b"audio-bytes")


async def test_command_invokes_spotdl_executable(tmp_path, monkeypatch):
    captured: dict[str, list[str]] = {}

    async def fake_spawn(cmd):
        captured["cmd"] = list(cmd)
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    await run_spotdl("spotify:album:x", tmp_path)
    cmd = captured["cmd"]
    assert cmd[0] == "spotdl"
    assert cmd[1] == "download"
    assert "spotify:album:x" in cmd
    assert "--output" in cmd
    out_idx = cmd.index("--output")
    output_val = cmd[out_idx + 1]
    assert output_val.startswith(str(tmp_path.resolve()))
    assert output_val.endswith("{title}-{artist}.{output-ext}")


async def test_embed_lyrics_flag_added_when_true(tmp_path, monkeypatch):
    captured: dict[str, list[str]] = {}

    async def fake_spawn(cmd):
        captured["cmd"] = list(cmd)
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    await run_spotdl("spotify:track:abc", tmp_path, embed_lyrics=True)
    assert "--lyrics" in captured["cmd"]


async def test_embed_lyrics_flag_absent_by_default(tmp_path, monkeypatch):
    captured: dict[str, list[str]] = {}

    async def fake_spawn(cmd):
        captured["cmd"] = list(cmd)
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    await run_spotdl("spotify:track:abc", tmp_path)
    assert "--lyrics" not in captured["cmd"]


async def test_spotdl_executable_env_override(tmp_path, monkeypatch):
    captured: dict[str, list[str]] = {}

    async def fake_spawn(cmd):
        captured["cmd"] = list(cmd)
        return FakeProc(returncode=0)

    monkeypatch.setenv("SPOTDL_EXECUTABLE", "/opt/spotdl/bin/spotdl")
    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    await run_spotdl("spotify:track:abc", tmp_path)
    assert captured["cmd"][0] == "/opt/spotdl/bin/spotdl"


async def test_multiple_files_produced(tmp_path, monkeypatch):
    async def fake_spawn(cmd):
        (tmp_path / "a.mp3").write_bytes(b"a")
        (tmp_path / "b.flac").write_bytes(b"bb")
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    results = await run_spotdl("spotify:album:m", tmp_path)
    paths = sorted(r.path for r in results)
    assert len(paths) == 2
    assert paths[0].endswith("a.mp3")
    assert paths[1].endswith("b.flac")


async def test_existing_files_not_returned(tmp_path, monkeypatch):
    (tmp_path / "preexisting.mp3").write_bytes(b"old")

    async def fake_spawn(cmd):
        (tmp_path / "new.mp3").write_bytes(b"new")
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    results = await run_spotdl("spotify:track:y", tmp_path)
    assert len(results) == 1
    assert results[0].path.endswith("new.mp3")


async def test_non_audio_files_ignored(tmp_path, monkeypatch):
    async def fake_spawn(cmd):
        (tmp_path / "song.mp3").write_bytes(b"x")
        (tmp_path / "log.txt").write_bytes(b"y")
        (tmp_path / "thumbnail.jpg").write_bytes(b"z")
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    results = await run_spotdl("spotify:track:z", tmp_path)
    paths = [r.path for r in results]
    assert any(p.endswith("song.mp3") for p in paths)
    assert not any(p.endswith("log.txt") for p in paths)
    assert not any(p.endswith("thumbnail.jpg") for p in paths)


async def test_nested_audio_files_picked_up(tmp_path, monkeypatch):
    nested = tmp_path / "Artist" / "Album"

    async def fake_spawn(cmd):
        nested.mkdir(parents=True)
        (nested / "01-track.opus").write_bytes(b"abc")
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    results = await run_spotdl("spotify:album:n", tmp_path)
    assert len(results) == 1
    assert results[0].path.endswith("01-track.opus")


async def test_output_dir_created_when_missing(tmp_path, monkeypatch):
    target = tmp_path / "deep" / "subdir"

    async def fake_spawn(cmd):
        (target / "ok.mp3").write_bytes(b"x")
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    results = await run_spotdl("spotify:track:q", target)
    assert target.exists() and target.is_dir()
    assert len(results) == 1


async def test_no_new_files_returns_empty(tmp_path, monkeypatch):
    async def fake_spawn(cmd):
        # spotDL exits 0 but produces nothing — already-on-disk dedupe case
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    results = await run_spotdl("spotify:track:none", tmp_path)
    assert results == []


# ---- non-zero exit raises SpotdlError ------------------------------------


async def test_non_zero_exit_raises_spotdl_error(tmp_path, monkeypatch):
    async def fake_spawn(cmd):
        return FakeProc(
            returncode=1,
            stderr=b"ConnectionError: could not resolve youtube.com",
        )

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    with pytest.raises(SpotdlError) as exc:
        await run_spotdl("spotify:track:bad", tmp_path)
    assert exc.value.exit_code == 1
    assert "ConnectionError" in exc.value.stderr_tail


async def test_failure_does_not_return_any_files(tmp_path, monkeypatch):
    """If spotDL fails, partially-written files must not be reported."""

    async def fake_spawn(cmd):
        # spotDL writes a partial file then crashes
        (tmp_path / "partial.mp3").write_bytes(b"truncated")
        return FakeProc(returncode=2, stderr=b"boom")

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    with pytest.raises(SpotdlError):
        await run_spotdl("spotify:track:partial", tmp_path)


async def test_stderr_tail_truncated(tmp_path, monkeypatch):
    huge = b"x" * 100_000

    async def fake_spawn(cmd):
        return FakeProc(returncode=1, stderr=huge)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    with pytest.raises(SpotdlError) as exc:
        await run_spotdl("spotify:track:noisy", tmp_path)
    assert len(exc.value.stderr_tail) <= 4_000


# ---- N10: typed error classification --------------------------------------


@pytest.mark.parametrize(
    "tail,expected_cls",
    [
        ("ConnectionError: could not resolve youtube.com", NetworkError),
        ("requests.exceptions.ConnectionError: Max retries exceeded", NetworkError),
        ("urllib3.exceptions.NewConnectionError: connection refused", NetworkError),
        ("socket.timeout: timed out", NetworkError),
        ("ssl.SSLError: TLS handshake failure", NetworkError),
        ("HTTP Error 429: Too Many Requests", RateLimitedError),
        ("yt_dlp rate limit exceeded", RateLimitedError),
        ("ERROR: Video unavailable", VideoUnavailableError),
        ("This video is not available in this app", VideoUnavailableError),
        ("Private video. Sign in if you've been granted access", VideoUnavailableError),
        ("This video is not available in your country", RegionLockedError),
        ("Geo restricted content", RegionLockedError),
        ("Sign in to confirm your age", AgeGatedError),
        ("This video is age-restricted", AgeGatedError),
        ("ffmpeg returned non-zero exit code", TranscodeError),
        ("Invalid data found when processing input", TranscodeError),
        ("KeyError: 'videoDetails'", UnknownSpotdlError),
        ("", UnknownSpotdlError),
    ],
)
def test_classify_error_matches_expected_subclass(tail, expected_cls):
    assert _classify_error(1, tail) is expected_cls


def test_classify_rate_limit_wins_over_network():
    # Rate-limited responses often include socket-y noise in the trace.
    tail = "HTTP Error 429: Too Many Requests\nConnectionError during retry"
    assert _classify_error(1, tail) is RateLimitedError


async def test_run_spotdl_raises_classified_subclass(tmp_path, monkeypatch):
    async def fake_spawn(cmd):
        return FakeProc(returncode=1, stderr=b"HTTP Error 429: Too Many Requests")

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    with pytest.raises(RateLimitedError) as exc:
        await run_spotdl("spotify:track:throttled", tmp_path)
    # Subclass is also a SpotdlError — preserves existing `except SpotdlError`.
    assert isinstance(exc.value, SpotdlError)
    assert exc.value.exit_code == 1


async def test_run_spotdl_unknown_classification_falls_back(tmp_path, monkeypatch):
    async def fake_spawn(cmd):
        return FakeProc(returncode=2, stderr=b"weird internal panic xyz")

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)

    with pytest.raises(UnknownSpotdlError):
        await run_spotdl("spotify:track:weird", tmp_path)
