from dataclasses import replace

from app.services.recommenders.base import RecommendedTrack

# Multiplier for items the user was shown recently. Demotes, never excludes:
# a small seed set must still be able to fill the feed.
SHOWN_PENALTY = 0.3
PER_ARTIST = 2


def rerank(
    candidates: list[RecommendedTrack],
    *,
    excluded: set[str],
    recently_shown: set[str],
    limit: int,
    per_artist: int = PER_ARTIST,
) -> list[RecommendedTrack]:
    """Engine-agnostic per-user re-rank (PLAN.md §5.5).

    Drops `excluded` URLs, demotes `recently_shown` ones, then picks greedily
    by score with at most `per_artist` tracks per (case-insensitive) artist.
    A missing score (engines without one) falls back to input position.
    """
    # ponytail: song-level only; add artist-level dislike if dismissals cluster by artist.
    scored: list[RecommendedTrack] = []
    for i, t in enumerate(candidates):
        if t.source_url in excluded:
            continue
        score = t.score if t.score is not None else 1.0 / (1 + 0.1 * i)
        if t.source_url in recently_shown:
            score *= SHOWN_PENALTY
        scored.append(replace(t, score=score))

    # sorted() is stable, so equal scores keep engine order.
    scored.sort(key=lambda t: t.score or 0.0, reverse=True)

    out: list[RecommendedTrack] = []
    per: dict[str, int] = {}
    for t in scored:
        key = t.artist.strip().lower()
        if per.get(key, 0) >= per_artist:
            continue
        per[key] = per.get(key, 0) + 1
        out.append(t)
        if len(out) >= limit:
            break
    return out
