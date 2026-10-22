# Citation Assistant

English | [简体中文](README.zh-CN.md)

> An academic citation assistant for Codex, Claude Code, and Cursor, designed for manuscript writing, BibTeX generation, and literature quality assessment.

Search academic literature through the Semantic Scholar API, automatically fall back to CrossRef during persistent rate limiting, and keep the source of each result explicit. Combine CCF rankings, JCR quartiles, Chinese Academy of Sciences (CAS) journal tiers, impact factors, and author H-indices to assess candidates, generate BibTeX, and produce recommendations. The current Skill workflow produces recommendation reports in Chinese.

This repository serves two audiences:

- **GitHub users**: read `README.md` or `README.zh-CN.md` for features, installation, and examples.
- **Skill runtimes (Codex / Claude Code / Cursor)**: read `SKILL.md` and follow its scripts and workflow.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 🔍 **Context-aware literature search** | Use Semantic Scholar to find papers relevant to the citation's context, with queries constructed by the assistant. |
| 🛡️ **Reference verification** | Retrieve BibTeX through DOI resolution to verify references instead of inventing citation metadata. |
| 📊 **Quality assessment** | Review venue metrics (CCF ranking, JCR quartile, CAS tier, impact factor) and author metrics (H-index, citation count). |
| 📝 **BibTeX generation** | Generate BibTeX entries for use in LaTeX documents. |
| 📋 **Recommendation reports** | Present structured results and explain why each candidate fits the manuscript. |

---

## 🚀 Installation

Requires Bash, `curl` (7.55.0+), `jq`, and a version of `sqlite3` that supports `-json`. On Windows, install and run through WSL. Online searches require network access; local venue database queries do not require an API key.

### Codex

Install for your user account to make the Skill available across projects:

```bash
mkdir -p ~/.agents/skills
git clone https://github.com/ZhangNy301/citation-assistant.git ~/.agents/skills/citation-assistant

# Optional: create .env in the installation directory and enter your S2_API_KEY.
# Do not overwrite an existing .env file.
cp -n ~/.agents/skills/citation-assistant/.env.example ~/.agents/skills/citation-assistant/.env
```

Alternatively, install only for a manuscript project by running the following from that project's root. Choose either this or the user-level installation:

```bash
mkdir -p .agents/skills
git clone https://github.com/ZhangNy301/citation-assistant.git .agents/skills/citation-assistant
```

Invoke the Skill in Codex:

```text
$citation-assistant Assess the quality of Nature Medicine and explain the sources of the metrics.
```

Natural-language requests such as “Find references for this paragraph” can also trigger the Skill. Restart Codex if it does not appear after installation. See the [official Codex Skills documentation](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills) for discovery paths.

Verify a user-level installation from any manuscript directory, without network access:

```bash
bash "$HOME/.agents/skills/citation-assistant/scripts/venue_info.sh" "Nature Medicine"
```

For a project-level installation, replace the path with the absolute path to that project's `.agents/skills/citation-assistant` directory. All clients share the same `SKILL.md`, scripts, and databases. There is no need to set `CLAUDE_SKILL_ROOT`.

### Claude Code

```bash
# Clone the repository.
git clone https://github.com/ZhangNy301/citation-assistant.git

# Copy the Skill into Claude Code's skills directory.
mkdir -p ~/.claude/skills/citation-assistant
cp citation-assistant/SKILL.md ~/.claude/skills/citation-assistant/
cp -r citation-assistant/scripts ~/.claude/skills/citation-assistant/
cp -r citation-assistant/data ~/.claude/skills/citation-assistant/

# Configure an API key (recommended).
echo 'S2_API_KEY="your_key_here"' > ~/.claude/skills/citation-assistant/.env
```

### Cursor

```bash
# Create the skills directory and clone the repository.
mkdir -p ~/.cursor/skills
cd ~/.cursor/skills
git clone https://github.com/ZhangNy301/citation-assistant.git

# Configure an API key (recommended).
echo 'S2_API_KEY="your_key_here"' > ~/.cursor/skills/citation-assistant/.env
```

Request an API key from [Semantic Scholar](https://www.semanticscholar.org/product/api).

---

## 📦 Available scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `search_papers.sh` | Default search: S2 relevance search, then CrossRef after persistent HTTP 429 responses | `bash scripts/search_papers.sh "query" [limit]` |
| `s2_search.sh` | Retrieve a small set of relevant S2 results, including arXiv status | `bash scripts/s2_search.sh "query" [limit]` |
| `s2_bulk_search.sh` | Retrieve candidates from the S2 bulk endpoint and return the first N records using a local limit | `bash scripts/s2_bulk_search.sh "query" "year_range" limit` |
| `author_info.sh` | Look up an author's H-index | `bash scripts/author_info.sh "author_id"` |
| `venue_info.sh` | Query combined venue quality metrics | `bash scripts/venue_info.sh "venue_name"` |
| `ccf_lookup.sh` | Look up CCF rankings | `bash scripts/ccf_lookup.sh "venue_name"` |
| `if_lookup.sh` | Look up journal impact factors | `bash scripts/if_lookup.sh "journal_name"` |
| `doi2bibtex.sh` | Convert a DOI to BibTeX | `bash scripts/doi2bibtex.sh "doi"` |
| `crossref_search.sh` | Search CrossRef directly as a fallback | `bash scripts/crossref_search.sh "query" [limit]` |

> Use `search_papers.sh` for everyday searches (limit: 1–100), or `s2_search.sh` when only S2 results are acceptable. Use `s2_bulk_search.sh` to retrieve a batch of candidates before filtering them locally.

---

## 🆕 Additional capabilities

### arXiv citation assessment

S2 search results are labeled according to their arXiv status and citation count:

| Status | Condition | Recommendation |
|--------|-----------|----------------|
| `recommended` | arXiv paper with ≥ 100 citations | ✅ Highly cited arXiv paper; consider citing. |
| `caution` | arXiv paper with < 100 citations | ⚠️ Low citation count; assess carefully. |
| `normal` | Not identified as arXiv by the venue check | Check the publication venue and version. |

### Author information

S2 search results include IDs for the first three authors, which can be used to look up their H-indices:

```bash
bash scripts/author_info.sh "18119920"
```

Example response:

```json
{
  "name": "Daquan Zhou",
  "hIndex": 25,
  "citations": 8500,
  "papers": 42
}
```

---

## 📁 Repository structure

```text
citation-assistant/
├── SKILL.md               # Skill instructions
├── README.md              # English documentation (this file)
├── README.zh-CN.md        # Chinese documentation
├── CHANGELOG.md           # Version history
├── .env.example           # Configuration template
├── agents/openai.yaml     # Codex display metadata and default prompt
├── tests/                 # Offline installation and script regression tests
├── scripts/               # Shell scripts
│   ├── init.sh
│   ├── s2_request.sh       # S2 requests, pacing, and bounded retries
│   ├── search_papers.sh    # Default search with labeled S2 → CrossRef fallback
│   ├── s2_search.sh
│   ├── s2_bulk_search.sh
│   ├── author_info.sh
│   ├── venue_info.sh
│   ├── ccf_lookup.sh
│   ├── if_lookup.sh
│   ├── doi2bibtex.sh
│   └── crossref_search.sh
└── data/                  # Databases
    ├── ccf_2026.sqlite
    ├── ccf_2026.jsonl
    └── impact_factor.sqlite3
```

---

## 🔧 Configuration

### Semantic Scholar API key

Request a key from [Semantic Scholar](https://www.semanticscholar.org/product/api).

| Mode | Rate limit |
|------|------------|
| With an API key | Initial allowance of 1 request/second across endpoints; throttling can still occur. |
| Without an API key | Shared quota; HTTP 429 responses are common. |

Place `.env` in the installed Skill's root directory. For a Codex user-level installation, this is `~/.agents/skills/citation-assistant/.env`; for a project installation, it is `<manuscript-project>/.agents/skills/citation-assistant/.env`. Claude Code and Cursor use their respective installation directories. Without `.env`, scripts also accept an exported `S2_API_KEY`. Values specified in `.env` take precedence over environment variables.

### Semantic Scholar rate limiting and retries

The three S2 scripts share request handling. HTTP 429 responses are retried at most twice by default. The scripts honor `Retry-After` (seconds or an HTTP date); if it is missing or cannot be parsed, they wait 2 and then 4 seconds. If the requested wait exceeds the configured maximum, they stop rather than retry early. HTTP 401/403 responses are not retried and prompt a credentials or endpoint-permissions check. Diagnostics go to stderr; stdout contains only the final successful results.

Configure these settings in the Skill's `.env`:

```bash
S2_MIN_INTERVAL=1       # Minimum interval between local sequential requests (seconds).
S2_MAX_RETRIES=2        # Retry count; 0 disables retries.
S2_RETRY_DELAY=2        # Initial backoff without Retry-After (seconds).
S2_MAX_RETRY_DELAY=60   # Maximum wait for a single retry (seconds).
```

Values must be integers from 0 to 99999. Local pacing does not coordinate concurrent processes or devices, so avoid parallel requests when sharing a key. An authenticated author request returning 200 does not guarantee that search endpoints will avoid throttling, and 429 does not mean the key is invalid. If bounded retries fail, wait longer, check other applications using the key, or contact Semantic Scholar about its quota. Paper searches can use `crossref_search.sh` instead. See the [official API tutorial](https://www.semanticscholar.org/product/api/tutorial).

### Search during persistent HTTP 429 responses

```bash
bash scripts/search_papers.sh "remote photoplethysmography" 2
```

Automatic fallback searches only CrossRef journal articles, proceedings articles, and posted content such as preprints (`journal-article` / `proceedings-article` / `posted-content`). This excludes supplementary components from paper candidates. Results include `work_type`. Direct calls to `crossref_search.sh` still search all types by default; pass `papers` as the third argument to enable this filter.

The entry point first runs S2 relevance search. It calls CrossRef only when the final error after retries is HTTP 429. Authentication errors, network errors, and empty results are not hidden by switching sources. If both sources fail, the script exits with a nonzero status and does not emit partial results.

Each result includes `source`, `search_method`, and `fallback_reason`. S2 results retain author IDs, relevance ordering, and the existing quality fields. CrossRef results explicitly use `source: "crossref"` and `search_method: "bibliographic"`; author IDs, arXiv IDs, and arXiv detection are `null`, while `arxiv_status` is `unknown`. Citation counts belong to their respective sources and are not interchangeable; missing counts are `null`. CrossRef does not provide the S2 author's H-index, so it must not be invented. Candidates still need to be checked against the manuscript's claims, and BibTeX should still be verified using the DOI script.

This entry point prevents persistent throttling of one source from blocking the whole search. It does not remove S2's server-side limits or guarantee CrossRef availability. The original `s2_search.sh`, `s2_bulk_search.sh`, and `author_info.sh` remain available independently and return failures on persistent HTTP 429 responses.

### arXiv citation threshold (optional)

```bash
# Default: 100. Configure it in .env if needed.
echo 'ARXIV_CITATION_THRESHOLD=100' >> ~/.agents/skills/citation-assistant/.env
```

---

## 📊 Quality assessment dimensions

| Dimension | Weight | Calculation |
|-----------|--------|-------------|
| CCF ranking | Base score | A=100, B=70, C=40 |
| JCR quartile | Base score | Q1=80, Q2=60, Q3=40, Q4=20 |
| CAS journal tier | Base score | Tier 1=90, Tier 2=70, Tier 3=50, Tier 4=30 |
| Impact factor | 30% | IF × 5 (maximum 50) |
| Citation count | 20% | log₁₀(citations+1) × 10 (maximum 50) |
| Publication year | 10% | (year−2015) × 2 (maximum 30) |
| Author H-index | 10% | First author's H-index × 2 (maximum 30) |

---

## 📖 Usage examples

These are requests you can make directly in Codex, Claude Code, or Cursor.

### Example 1: Find citations for a LaTeX paragraph

```text
I'm writing a paper and need references for this paragraph:

"Deep learning has achieved remarkable success in medical image analysis, particularly in radiology where chest X-rays are the most commonly performed imaging examination globally [CITE]. Recent advances in vision transformers have further improved performance on these tasks [CITE]."

Find suitable references for each placeholder.
```

### Example 2: Assess a journal

```text
I'm considering submitting to TMI (IEEE Transactions on Medical Imaging).
What is its CCF ranking and impact factor?
```

### Example 3: Assess an author's academic impact

```text
What is the H-index of this paper's first author? I'd like to assess their academic impact.
```

### Example 4: Generate BibTeX

```text
Generate BibTeX for this paper:
DOI: 10.1038/s41591-020-0792-9
```

### Example 5: Bulk search with a year filter

```text
Find high-quality papers on remote photoplethysmography (rPPG) published from 2020 onward and recommend 10.
```

Use `s2_bulk_search.sh` to retrieve candidates in a batch, then assess them using publication year, citation counts, and venue quality.

### Example 6: Review citations in a manuscript paragraph

Ask the assistant to check the references and suggest better candidates where appropriate:

```text
Remote photoplethysmography (rPPG) enables non-contact heart rate estimation from facial videos [1]. Traditional methods like CHROM and POS have been widely used [2], while recent deep learning approaches have shown superior performance [3].

[1] Some arXiv paper with 5 citations
[2] A conference paper from 2015
[3] Another paper
```

---

## 🧪 Development and validation

After installing the runtime dependencies, run the following from the repository root. Tests also require Python 3:

```bash
python3 -m unittest discover -s tests -v
```

Tests run in temporary installation directories. They cover paths containing spaces, calls from manuscript directories, configuration loading, local database queries, simulated API searches, author information, HTTP 429 recovery, CrossRef fallback and failures, source labels, and BibTeX. They do not consume real API quota. GitHub Actions runs the same tests on Linux and macOS.

To reproduce live API validation, configure a key in your local `.env`, then explicitly run:

```bash
python3 tests/live_search_smoke.py --rounds 2
```

See the [S2 HTTP 429 diagnosis notes](docs/s2-rate-limit-diagnosis.md) (in Chinese) for the investigation and known limitations.

The live test searches three fixed topics sequentially, checks source labels, publication types, and unknown fields, then retrieves BibTeX through DOI resolution. `--rounds` accepts 1–3. It consumes real API quota and can fail when external services are unavailable. CI does not run it, and no key needs to be uploaded.

## 🙏 Acknowledgments

- [Semantic Scholar](https://www.semanticscholar.org/) — Academic paper search API
- [impact_factor](https://github.com/suqingdong/impact_factor) — Journal impact factor database
- [CrossRef](https://www.crossref.org/) — DOI metadata API

## 📖 Related links

- [Xiaohongshu tutorial: automating literature citations (Chinese)](https://www.xiaohongshu.com/discovery/item/699eecff000000000d00ab7d?source=webshare&xhsshare=pc_web&xsec_token=ABlbc1XDsjw8TWj8fUipbvyaj7qoU9u73hL5ZmzK4n65c=&xsec_source=pc_share)

## License

MIT
