"""Offline installation and CLI regression tests; no API credentials required."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]

# Stub only the HTTP boundary: the real shell scripts, jq and databases run.
CURL_STUB = r'''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
Path(os.environ["TEST_CURL_ARGS"]).write_text(json.dumps(args))
url = next(arg for arg in args if arg.startswith("https://"))
status = os.environ.get("TEST_HTTP_STATUS", "200")
paper = {
    "title": "Fixture paper", "year": 2024, "venue": "arXiv",
    "citationCount": 150, "externalIds": {"DOI": "10.1234/test", "ArXiv": "2401.00001"},
    "url": "https://example.org/paper", "abstract": "Fixture abstract",
    "authors": [{"name": "Test Author", "authorId": "42"}]
}
if "api.semanticscholar.org" in url:
    if status != "200":
        body = {"message": "Fixture error"}
    elif "/author/" in url:
        body = {"name": "Test Author", "hIndex": 12, "citationCount": 345,
                "paperCount": 20}
    else:
        body = {"total": 2, "data": [paper, dict(paper, title="Second paper")]}
    print(json.dumps(body))
    print(status)
elif "api.crossref.org" in url:
    print(json.dumps({"message": {"items": [{
        "title": ["CrossRef fixture"], "DOI": "10.1234/test",
        "published-print": {"date-parts": [[2024]]},
        "container-title": ["Test Journal"],
        "author": [{"given": "Test", "family": "Author"}]
    }]}}))
elif "doi.org/" in url:
    print("@article{fixture2024, title={Fixture paper}, doi={10.1234/test}}")
else:
    sys.exit("Unexpected HTTP request: " + url)
'''


class SkillTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="citation skill ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.paper = self.root / "paper project"
        self.paper.mkdir()
        self.install = self.root / ".agents/skills/citation-assistant"
        self.install.mkdir(parents=True)
        for name in ("scripts", "data", "agents"):
            shutil.copytree(REPO / name, self.install / name)
        shutil.copy2(REPO / "SKILL.md", self.install)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        curl = self.bin / "curl"
        curl.write_text(CURL_STUB)
        curl.chmod(0o755)
        self.env = os.environ.copy()
        for key in ("S2_API_KEY", "ARXIV_CITATION_THRESHOLD", "CLAUDE_SKILL_ROOT",
                    "SKILL_ROOT", "SKILL_DATA_DIR", "CITATION_ASSISTANT_ROOT", "TEST_HTTP_STATUS"):
            self.env.pop(key, None)
        self.env.update(PATH=str(self.bin) + os.pathsep + self.env["PATH"],
                        S2_MIN_INTERVAL="0",
                        S2_RATE_LIMIT_FILE=str(self.root / "rate limit"),
                        TEST_CURL_ARGS=str(self.root / "curl-args.json"))
        # An unrelated manuscript configuration must never be sourced.
        (self.paper / ".env").write_text("S2_API_KEY=wrong-project-key\n")

    def run_script(self, name, *args, expected=0):
        result = subprocess.run(["bash", str(self.install / "scripts" / name), *args],
                                cwd=self.paper, env=self.env, text=True,
                                capture_output=True, timeout=20)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    def curl_args(self):
        return json.loads(Path(self.env["TEST_CURL_ARGS"]).read_text())

    def configure(self):
        (self.install / ".env").write_text(
            'S2_API_KEY="fixture key"\nARXIV_CITATION_THRESHOLD=200\n')

    def test_shell_syntax(self):
        for script in (REPO / "scripts").glob("*.sh"):
            with self.subTest(script=script.name):
                subprocess.run(["bash", "-n", str(script)], check=True)

    def test_local_databases_from_manuscript_directory(self):
        ccf = json.loads(self.run_script("ccf_lookup.sh", "CVPR").stdout)
        self.assertEqual(ccf["acronym"], "CVPR")
        self.assertEqual(ccf["rank"], "A")
        journal = json.loads(self.run_script("if_lookup.sh", "Nature Medicine").stdout)
        self.assertGreater(journal["factor"], 0)
        venue = json.loads(self.run_script("venue_info.sh", "Nature Medicine").stdout)
        self.assertEqual(venue["summary"]["impact_factor"], journal["factor"])
        self.assertTrue(venue["impact_details"])

    def test_project_and_existing_client_installations(self):
        for location in (self.paper / ".agents/skills", self.root / ".claude/skills",
                         self.root / ".cursor/skills"):
            with self.subTest(location=str(location)):
                target = location / "citation-assistant"
                shutil.copytree(self.install, target)
                result = subprocess.run(
                    ["bash", str(target / "scripts/ccf_lookup.sh"), "CVPR"],
                    cwd=self.paper, env=self.env, text=True, capture_output=True, check=True)
                self.assertEqual(json.loads(result.stdout)["rank"], "A")

    def test_symlinked_skill_folder(self):
        target = self.root / "linked skill"
        target.symlink_to(self.install, target_is_directory=True)
        self.install = target
        self.assertEqual(json.loads(self.run_script("ccf_lookup.sh", "CVPR").stdout)["rank"], "A")
        self.configure()
        self.run_script("s2_search.sh", "test", "1")
        self.assertIn("x-api-key: fixture key", self.curl_args())

    def test_init_uses_own_installation(self):
        self.configure()
        self.env["CLAUDE_SKILL_ROOT"] = str(self.paper)
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; printf "%s\\n" "$SKILL_ROOT" "$SKILL_DATA_DIR" "$S2_API_KEY"',
             "test", str(self.install / "scripts/init.sh")],
            cwd=self.paper, env=self.env, text=True, capture_output=True, check=True)
        self.assertEqual(result.stdout.splitlines(),
                         [str(self.install), str(self.install / "data"), "fixture key"])

    def test_s2_config_and_query_encoding(self):
        self.env["S2_API_KEY"] = "overridden-environment-key"
        self.configure()
        self.env["CLAUDE_SKILL_ROOT"] = str(self.paper)
        result = self.run_script("s2_search.sh", "heart rate & video", "1")
        paper, _ = json.JSONDecoder().raw_decode(result.stdout)
        self.assertEqual(paper["arxiv_status"], "caution")
        self.assertEqual(paper["authors"][0]["id"], "42")
        self.assertIn("x-api-key: fixture key", self.curl_args())
        self.assertTrue(any("query=heart%20rate%20%26%20video&limit=1" in arg
                            for arg in self.curl_args()))
        self.assertTrue(Path(self.env["S2_RATE_LIMIT_FILE"]).exists())

    def test_s2_environment_key_without_env_file(self):
        self.env["S2_API_KEY"] = "environment-key"
        self.run_script("s2_search.sh", "test")
        self.assertIn("x-api-key: environment-key", self.curl_args())

    def test_s2_without_api_key(self):
        self.run_script("s2_search.sh", "test")
        self.assertFalse(any("x-api-key" in arg for arg in self.curl_args()))

    def test_bulk_limit_and_year_filter(self):
        self.configure()
        result = self.run_script("s2_bulk_search.sh", "test", "2020-", "1")
        paper = json.loads(result.stdout)  # Only one object despite two API results.
        self.assertEqual(paper["title"], "Fixture paper")
        self.assertEqual(paper["arxiv_status"], "caution")
        self.assertIn("x-api-key: fixture key", self.curl_args())
        self.assertTrue(any("year=2020-" in arg for arg in self.curl_args()))

    def test_bulk_invalid_limit(self):
        for limit in ("0", "-1", "abc", "1.5"):
            with self.subTest(limit=limit):
                result = self.run_script("s2_bulk_search.sh", "test", "", limit, expected=1)
                self.assertIn("positive integer", result.stderr)
        self.assertFalse(Path(self.env["TEST_CURL_ARGS"]).exists())

    def test_author_info(self):
        self.configure()
        author = json.loads(self.run_script("author_info.sh", "42").stdout)
        self.assertEqual((author["hIndex"], author["citations"], author["papers"]), (12, 345, 20))
        self.assertIn("x-api-key: fixture key", self.curl_args())

    def test_rate_limit_errors_and_crossref_fallback(self):
        self.env["TEST_HTTP_STATUS"] = "429"
        for name in ("s2_search.sh", "s2_bulk_search.sh", "author_info.sh"):
            with self.subTest(script=name):
                result = self.run_script(name, "test", expected=1)
                self.assertIn("Rate limit", json.loads(result.stderr)["error"])
                self.assertEqual(result.stdout, "")
        result = self.run_script("crossref_search.sh", "test", "1")
        self.assertEqual(json.loads(result.stdout)["doi"], "10.1234/test")

    def test_author_not_found(self):
        self.env["TEST_HTTP_STATUS"] = "404"
        result = self.run_script("author_info.sh", "42", expected=1)
        self.assertEqual(json.loads(result.stderr)["error"], "Author not found")

    def test_doi_to_bibtex(self):
        result = self.run_script("doi2bibtex.sh", "https://doi.org/10.1234/test")
        self.assertTrue(result.stdout.startswith("@article{"))
        self.assertIn("https://doi.org/10.1234/test", self.curl_args())
        self.assertIn("Accept: text/bibliography; style=bibtex", self.curl_args())

    def test_missing_arguments(self):
        for script in (self.install / "scripts").glob("*.sh"):
            if script.name == "init.sh":
                continue
            with self.subTest(script=script.name):
                result = self.run_script(script.name, expected=1)
                self.assertIn("Usage:", result.stderr)


if __name__ == "__main__":
    unittest.main()
