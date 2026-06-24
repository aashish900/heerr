# PLAN.md — backend

Detailed implementation plans for upcoming milestones. Each section maps to a
roadmap phase. Remove a section once its milestone is committed and its
CHANGELOG entry exists.

---

## Phase L — Lyrics embedding via spotDL (`SPOTDL_EMBED_LYRICS`)

**Roadmap milestone:** L1  
**Goal:** Let operators opt-in to embedding lyrics in every downloaded MP3 by
setting one env variable. No UI change; purely a backend flag.

### How spotDL handles lyrics

`spotdl download <url> --lyrics` passes the `--lyrics` flag, which causes
spotDL to fetch lyrics from its built-in providers (Genius, AZLyrics, etc.)
and embed them as an `USLT` ID3 tag in the output MP3. The flag is additive —
it does not change the output filename or path.

### Files to change

#### 1. `backend/app/config.py`

Add one field to the `Settings` (pydantic-settings) class, after the existing
`preview_*` fields:

```python
# Lyrics embedding. When true, passes --lyrics to spotDL so downloaded
# MP3s carry embedded lyrics from spotDL's default providers.
spotdl_embed_lyrics: bool = False
```

pydantic-settings maps this to the env var `SPOTDL_EMBED_LYRICS` (case-
insensitive). Env var absent → `False` (default, current behaviour preserved).

#### 2. `backend/app/services/spotdl_runner.py`

Change the signature of `run_spotdl` to accept a keyword-only `embed_lyrics`
flag:

```python
async def run_spotdl(
    source_url: str,
    output_dir: str | Path,
    *,
    embed_lyrics: bool = False,
) -> list[DownloadedFile]:
```

After the existing `cmd` list construction, append `"--lyrics"` conditionally:

```python
if embed_lyrics:
    cmd.append("--lyrics")
```

The rest of the function (spawn, communicate, diff, error-classify) is
unchanged.

**Type alias compatibility:** `SpotdlRunner = Callable[[str, str], Awaitable[list[DownloadedFile]]]`
(in `workers.py`) takes only the two positional args. The new `embed_lyrics`
kwarg has a default so `run_spotdl("url", "dir")` still type-checks. However,
`get_enqueuer` must bind the flag before handing the callable to `JobEnqueuer`
— see step 3.

#### 3. `backend/app/services/workers.py`

Use `functools.partial` to bind the flag at enqueuer construction time, keeping
the `SpotdlRunner` positional contract intact for the rest of the codebase:

```python
from functools import partial

def get_enqueuer() -> JobEnqueuer:
    settings = get_settings()
    runner = partial(run_spotdl, embed_lyrics=settings.spotdl_embed_lyrics)
    return JobEnqueuer(
        sm=_sessionmaker(),
        runner=runner,           # still callable as runner(url, dir)
        output_dir=settings.music_output_dir,
    )
```

#### 4. `.env.example` (repo root)

Add a commented block after the `PREVIEW_CACHE_TTL_S` section:

```bash
# === Lyrics embedding (Phase L) =============================================
# When true, passes --lyrics to spotDL so downloaded MP3s carry embedded
# lyrics from spotDL's default providers. Default is false.
# SPOTDL_EMBED_LYRICS=false
```

### Tests to add — `backend/tests/test_spotdl_runner.py`

Reuse the existing `monkeypatch + FakeProc` pattern already in the file. Add
two new async test functions after the existing ones:

```python
@pytest.mark.asyncio
async def test_embed_lyrics_flag_added_when_true(tmp_path, monkeypatch):
    captured: dict[str, list[str]] = {}

    async def fake_spawn(cmd: list[str]):
        captured["cmd"] = list(cmd)
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)
    await run_spotdl("spotify:track:abc", tmp_path, embed_lyrics=True)
    assert "--lyrics" in captured["cmd"]


@pytest.mark.asyncio
async def test_embed_lyrics_flag_absent_by_default(tmp_path, monkeypatch):
    captured: dict[str, list[str]] = {}

    async def fake_spawn(cmd: list[str]):
        captured["cmd"] = list(cmd)
        return FakeProc(returncode=0)

    monkeypatch.setattr("app.services.spotdl_runner._spawn", fake_spawn)
    await run_spotdl("spotify:track:abc", tmp_path)
    assert "--lyrics" not in captured["cmd"]
```

(`FakeProc` is already defined in that test file for existing subprocess tests.)

### Docs

- Append one CHANGELOG entry under the commit date.
- No new ADR needed (small config addition, no architectural change).
- Bump `backend/docs/ROADMAP.md` L1 box from `[ ]` to `[x]`.

### Verification

```bash
cd backend
poetry run pytest tests/test_spotdl_runner.py -v    # new flag tests
poetry run pytest                                     # full suite
ruff check app/ && mypy app/                         # lint + types
```

Smoke test (optional, on the real stack):
```bash
SPOTDL_EMBED_LYRICS=true  # set in .env, restart container
# download a track, then:
eyeD3 /music/<track>.mp3 | grep -i lyric
# or: exiftool <track>.mp3 | grep -i lyric
```

### Commit message

```
feat(backend): L1 — SPOTDL_EMBED_LYRICS toggle — embed lyrics in downloaded MP3s
```

---
