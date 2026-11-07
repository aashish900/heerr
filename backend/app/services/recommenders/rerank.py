import re
from dataclasses import replace

from app.services.recommenders.base import RecommendedTrack

# Multiplier for items the user was shown recently. Demotes, never excludes:
# a small seed set must still be able to fill the feed.
SHOWN_PENALTY = 0.3
PER_ARTIST = 2

# Covers / alternate versions are not "new songs" (RX7a). Words that never occur in a
# real title match anywhere; ambiguous ones ("Live Forever", "Cover Me Up") only count
# inside (...)/[...] or after a " - " / " | " qualifier.
_ALT_ANYWHERE = re.compile(r"\b(mashup|karaoke|slowed|reverb|lo-?fi|sped up|nightcore)\b", re.I)
_ALT_QUALIFIED = re.compile(
    r"\b(cover|live|acoustic|remix|version|instrumental|unplugged|reprise)\b", re.I
)
_QUALIFIERS = re.compile(r"\(([^)]*)\)|\[([^\]]*)\]|\s[-\u2013\u2014|]\s(.*)$")


def is_alt_version(title: str) -> bool:
    if _ALT_ANYWHERE.search(title):
        return True
    quals = " ".join(g for m in _QUALIFIERS.finditer(title) for g in m.groups() if g)
    return bool(_ALT_QUALIFIED.search(quals))


def rerank(
    candidates: list[RecommendedTrack],
    *,
    excluded: set[str],
    recently_shown: set[str],
    limit: int,
    per_artist: int = PER_ARTIST,
) -> list[RecommendedTrack]:
    """Engine-agnostic per-user re-rank (PLAN.md §5.5).

    Drops `excluded` URLs and covers/alternate versions, demotes `recently_shown` ones, then picks greedily
    by score with at most `per_artist` tracks per (case-insensitive) artist.
    Duplicate URLs keep their best-scored copy.
    A missing score (engines without one) falls back to input position.
    """
    # ponytail: song-level only; add artist-level dislike if dismissals cluster by artist.
    scored: list[RecommendedTrack] = []
    for i, t in enumerate(candidates):
        if t.source_url in excluded or is_alt_version(t.title):
            continue
        score = t.score if t.score is not None else 1.0 / (1 + 0.1 * i)
        if t.source_url in recently_shown:
            score *= SHOWN_PENALTY
        scored.append(replace(t, score=score))

    # sorted() is stable, so equal scores keep engine order.
    scored.sort(key=lambda t: t.score or 0.0, reverse=True)

    out: list[RecommendedTrack] = []
    per: dict[str, int] = {}
    seen: set[str] = set()
    for t in scored:
        if t.source_url in seen:
            continue
        key = t.artist.strip().lower()
        if per.get(key, 0) >= per_artist:
            continue
        per[key] = per.get(key, 0) + 1
        seen.add(t.source_url)
        out.append(t)
        if len(out) >= limit:
            break
    return out
