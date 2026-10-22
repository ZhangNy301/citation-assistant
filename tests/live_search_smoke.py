"""Opt-in real API smoke test. Not discovered by unittest or run in CI.

Uses the scripts' local .env / S2_API_KEY configuration; never reads or prints keys.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time

REPO = Path(__file__).resolve().parents[1]
QUERIES = (
    "remote photoplethysmography",
    "vision transformer medical imaging",
    "graph neural network molecular property prediction",
)


def run(script, args, env, cwd):
    result = subprocess.run(
        ["bash", str(REPO / "scripts" / script), *args],
        cwd=cwd, env=env, capture_output=True, text=True, timeout=180,
    )
    if result.returncode:
        raise RuntimeError(f"{script} failed (exit {result.returncode}): {result.stderr.strip()}")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rounds", type=int, choices=range(1, 4), default=1)
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="citation live smoke ") as tmp:
        env = dict(os.environ, S2_RATE_LIMIT_FILE=str(Path(tmp) / "rate"), S2_MIN_INTERVAL="3")
        for round_number in range(1, args.rounds + 1):
            for query in QUERIES:
                start = time.monotonic()
                result = run("search_papers.sh", [query, "2"], env, tmp)
                papers = []
                remaining = result.stdout.strip()
                while remaining:
                    paper, end = json.JSONDecoder().raw_decode(remaining)
                    papers.append(paper)
                    remaining = remaining[end:].lstrip()
                assert len(papers) == 2, "Expected two candidate papers"
                sources = {paper["source"] for paper in papers}
                assert len(sources) == 1 and sources <= {"semantic_scholar", "crossref"}
                for paper in papers:
                    assert paper["title"] and isinstance(paper["authors"], list)
                    if paper["source"] == "crossref":
                        assert paper["fallback_reason"] == "semantic_scholar_http_429"
                        assert paper["work_type"] in ("journal-article", "proceedings-article", "posted-content")
                        assert paper["is_arxiv"] is None and paper["arxiv_status"] == "unknown"
                        assert all(author["id"] is None for author in paper["authors"])
                doi = next((paper.get("doi") for paper in papers if paper.get("doi")), None)
                assert doi, "No DOI available to verify"
                bibtex = run("doi2bibtex.sh", [doi], env, tmp).stdout
                assert re.search(r"@\w+\s*[{(]", bibtex), "DOI did not produce BibTeX"
                print(json.dumps({
                    "round": round_number, "query": query, "source": next(iter(sources)),
                    "papers": len(papers), "bibtex_verified": True,
                    "elapsed_seconds": round(time.monotonic() - start, 2),
                }), flush=True)
                time.sleep(3)


if __name__ == "__main__":
    main()
