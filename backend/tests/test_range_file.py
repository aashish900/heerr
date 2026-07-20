import pytest

from app.services.range_file import InvalidRangeError, iter_file_range, parse_range

# ---- parse_range --------------------------------------------------------------


def test_no_header_returns_none():
    assert parse_range(None, 1000) is None


def test_empty_header_returns_none():
    assert parse_range("", 1000) is None


def test_malformed_header_returns_none():
    assert parse_range("bytes=abc-def", 1000) is None


def test_full_range_start_end():
    assert parse_range("bytes=0-99", 1000) == (0, 99)


def test_open_ended_range():
    assert parse_range("bytes=500-", 1000) == (500, 999)


def test_suffix_range():
    assert parse_range("bytes=-100", 1000) == (900, 999)


def test_suffix_range_larger_than_file():
    assert parse_range("bytes=-5000", 1000) == (0, 999)


def test_end_clamped_to_file_size():
    assert parse_range("bytes=0-99999", 1000) == (0, 999)


def test_start_beyond_eof_raises():
    with pytest.raises(InvalidRangeError):
        parse_range("bytes=1000-1005", 1000)


def test_start_after_end_raises():
    with pytest.raises(InvalidRangeError):
        parse_range("bytes=500-100", 1000)


def test_empty_file_raises():
    with pytest.raises(InvalidRangeError):
        parse_range("bytes=0-10", 0)


# ---- iter_file_range ------------------------------------------------------


async def test_iter_file_range_full(tmp_path):
    p = tmp_path / "f.bin"
    data = bytes(range(256)) * 4
    p.write_bytes(data)

    chunks = [c async for c in iter_file_range(str(p), 0, len(data) - 1)]
    assert b"".join(chunks) == data


async def test_iter_file_range_slice(tmp_path):
    p = tmp_path / "f.bin"
    data = b"0123456789"
    p.write_bytes(data)

    chunks = [c async for c in iter_file_range(str(p), 2, 5)]
    assert b"".join(chunks) == b"2345"
