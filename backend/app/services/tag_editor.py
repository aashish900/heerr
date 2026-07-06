"""In-place tag editing for library audio files (issue #44).

Rewrites metadata tags (title / album / artist) and embeds cover art in the
file the backend already owns under `music_output_dir`. The file is **never
renamed or moved** — `Song.path`, offline manifests, and `downloads` dedupe
rows all key on the path staying stable. Navidrome picks the change up on its
next scan (the mtime bump from `save()` is enough to trigger a re-read).

All functions are synchronous (mutagen is sync); endpoint callers must
offload via `anyio.to_thread.run_sync`.
"""

import base64
from pathlib import Path

import mutagen
from mutagen.flac import FLAC, Picture
from mutagen.id3 import APIC, ID3, ID3NoHeaderError
from mutagen.mp4 import MP4, MP4Cover
from mutagen.oggopus import OggOpus
from mutagen.oggvorbis import OggVorbis

# .wav is deliberately excluded: RIFF tagging is nonstandard and Navidrome /
# players handle it inconsistently. spotDL's default output is .mp3, so wav
# is a corner case not worth the risk (see DECISIONLOG Phase O ADR).
EDITABLE_SUFFIXES = {".mp3", ".m4a", ".flac", ".ogg", ".opus"}

_JPEG_MAGIC = b"\xff\xd8\xff"
_PNG_MAGIC = b"\x89PNG\r\n\x1a\n"

# Front-cover picture type shared by ID3 APIC and the Vorbis/FLAC Picture block.
_FRONT_COVER = 3


class TagEditError(Exception):
    """Base class for tag-editing failures."""


class UnsupportedImageError(TagEditError):
    """Cover payload is not a JPEG or PNG."""


class TagWriteError(TagEditError):
    """mutagen could not parse or save the audio file."""


def sniff_image(data: bytes) -> str:
    """Return the MIME type of a cover payload from its magic bytes.

    The client-declared content-type is never trusted; only JPEG and PNG
    are accepted.
    """
    if data.startswith(_JPEG_MAGIC):
        return "image/jpeg"
    if data.startswith(_PNG_MAGIC):
        return "image/png"
    raise UnsupportedImageError("cover must be a JPEG or PNG image")


def write_tags(
    path: Path,
    *,
    title: str | None = None,
    album: str | None = None,
    artist: str | None = None,
) -> list[str]:
    """Rewrite the given tag fields in place; None fields are left untouched.

    Returns the list of field names actually written. Uses mutagen's easy-tag
    layer so `title` / `album` / `artist` map uniformly across ID3, MP4, and
    Vorbis comments.
    """
    audio = mutagen.File(path, easy=True)
    if audio is None:
        raise TagWriteError(f"unrecognised audio file: {path.name}")
    if audio.tags is None:
        audio.add_tags()
    written: list[str] = []
    for key, value in (("title", title), ("album", album), ("artist", artist)):
        if value is not None:
            audio[key] = [value]
            written.append(key)
    if written:
        audio.save()
    return written


def embed_cover(path: Path, data: bytes, mime: str) -> None:
    """Embed `data` as the file's single front cover, replacing any existing.

    Per-format: ID3 APIC (.mp3), MP4 `covr` (.m4a), FLAC picture block
    (.flac), base64 `metadata_block_picture` Vorbis comment (.ogg / .opus).
    """
    suffix = path.suffix.lower()
    if suffix == ".mp3":
        try:
            tags = ID3(path)
        except ID3NoHeaderError:
            tags = ID3()
        tags.delall("APIC")
        tags.add(APIC(encoding=3, mime=mime, type=_FRONT_COVER, desc="Cover", data=data))
        tags.save(path)
    elif suffix == ".m4a":
        mp4 = MP4(path)
        fmt = MP4Cover.FORMAT_JPEG if mime == "image/jpeg" else MP4Cover.FORMAT_PNG
        mp4["covr"] = [MP4Cover(data, imageformat=fmt)]
        mp4.save()
    elif suffix == ".flac":
        flac = FLAC(path)
        flac.clear_pictures()
        flac.add_picture(_picture(data, mime))
        flac.save()
    elif suffix in {".ogg", ".opus"}:
        ogg = OggVorbis(path) if suffix == ".ogg" else OggOpus(path)
        block = base64.b64encode(_picture(data, mime).write()).decode("ascii")
        ogg["metadata_block_picture"] = [block]
        ogg.save()
    else:
        raise TagWriteError(f"unsupported suffix for cover embed: {suffix}")


def _picture(data: bytes, mime: str) -> Picture:
    pic = Picture()
    pic.type = _FRONT_COVER
    pic.mime = mime
    pic.desc = "Cover"
    pic.data = data
    return pic
