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
import io

args = sys.argv[1:]
raw_args = list(args)
for i, arg in enumerate(args):
    if i > 0 and args[i - 1] == "-H" and arg.startswith("@"):
        args[i] = Path(arg[1:]).read_text().strip()
count_path = Path(os.environ["TEST_CURL_ARGS"] + ".count")
count = int(count_path.read_text()) if count_path.exists() else 0
count_path.write_text(str(count + 1))
sequence = os.environ.get("TEST_HTTP_SEQUENCE", "").split(",")
if sequence != [""]:
    os.environ["TEST_HTTP_STATUS"] = sequence[min(count, len(sequence) - 1)]
if os.environ.get("TEST_NETWORK_FAIL"):
    sys.exit(28)
stdout = sys.stdout
sys.stdout = io.StringIO()
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
output = sys.stdout.getvalue()
sys.stdout = stdout
if "--output" in raw_args:
    body, code = output.rstrip("\n").rsplit("\n", 1)
    Path(raw_args[raw_args.index("--output") + 1]).write_text(body)
    headers = "HTTP/1.1 " + code + " Status\r\n"
    if os.environ.get("TEST_RETRY_AFTER"):
        headers += "Retry-After: " + os.environ["TEST_RETRY_AFTER"] + "\r\n"
    Path(raw_args[raw_args.index("--dump-header") + 1]).write_text(headers + "\r\n")
    print(code, end="")
else:
    print(output, end="")
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
        sleep = self.bin / "sleep"
        sleep.write_text('#!/bin/bash\nprintf "%s\\n" "$1" >> "$TEST_SLEEP_LOG"\n')
        sleep.chmod(0o755)
        self.env = os.environ.copy()
        for key in ("S2_API_KEY", "ARXIV_CITATION_THRESHOLD", "CLAUDE_SKILL_ROOT",
                    "SKILL_ROOT", "SKILL_DATA_DIR", "CITATION_ASSISTANT_ROOT", "TEST_HTTP_STATUS", "TEST_HTTP_SEQUENCE", "TEST_NETWORK_FAIL",
                    "TEST_RETRY_AFTER", "S2_MAX_RETRIES", "S2_RETRY_DELAY", "S2_MAX_RETRY_DELAY"):
            self.env.pop(key, None)
        self.env.update(PATH=str(self.bin) + os.pathsep + self.env["PATH"],
                        S2_MIN_INTERVAL="0",
                        S2_RATE_LIMIT_FILE=str(self.root / "rate limit"),
                        TEST_CURL_ARGS=str(self.root / "curl-args.json"),
                        TEST_SLEEP_LOG=str(self.root / "sleeps"))
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
                self.assertIn("Rate limit", json.loads(result.stderr.splitlines()[-1])["error"])
                self.assertEqual(result.stdout, "")
        result = self.run_script("crossref_search.sh", "test", "1")
        self.assertEqual(json.loads(result.stdout)["doi"], "10.1234/test")

    def test_author_not_found(self):
        self.env["TEST_HTTP_STATUS"] = "404"
        result = self.run_script("author_info.sh", "42", expected=1)
        self.assertEqual(json.loads(result.stderr.splitlines()[-1])["error"], "Author not found")

    def test_doi_to_bibtex(self):
        result = self.run_script("doi2bibtex.sh", "https://doi.org/10.1234/test")
        self.assertTrue(result.stdout.startswith("@article{"))
        self.assertIn("https://doi.org/10.1234/test", self.curl_args())
        self.assertIn("Accept: text/bibliography; style=bibtex", self.curl_args())

    def request_count(self):
        return int(Path(self.env["TEST_CURL_ARGS"] + ".count").read_text())

    def sleeps(self):
        path = Path(self.env["TEST_SLEEP_LOG"])
        return path.read_text().splitlines() if path.exists() else []

    def test_429_recovers_without_polluting_stdout(self):
        self.env["TEST_HTTP_SEQUENCE"] = "429,429,200"
        result = self.run_script("author_info.sh", "42")
        self.assertEqual(json.loads(result.stdout)["name"], "Test Author")
        self.assertEqual(self.request_count(), 3)
        self.assertEqual(self.sleeps(), ["2", "4"])

    def test_429_retry_budget(self):
        self.env["TEST_HTTP_STATUS"] = "429"
        result = self.run_script("author_info.sh", "42", expected=1)
        self.assertEqual(self.request_count(), 3)
        self.assertEqual(result.stdout, "")
        self.assertIn("bounded retries", result.stderr)

    def test_retry_after_seconds(self):
        self.env.update(TEST_HTTP_SEQUENCE="429,200", TEST_RETRY_AFTER="7")
        self.run_script("author_info.sh", "42")
        self.assertEqual(self.sleeps(), ["7"])

    def test_retry_after_date(self):
        import email.utils
        import time
        self.env.update(TEST_HTTP_SEQUENCE="429,200",
                        TEST_RETRY_AFTER=email.utils.formatdate(time.time() + 30, usegmt=True))
        self.run_script("author_info.sh", "42")
        self.assertEqual(len(self.sleeps()), 1)
        self.assertTrue(20 <= int(self.sleeps()[0]) <= 30)

    def test_invalid_retry_after_uses_backoff(self):
        self.env.update(TEST_HTTP_SEQUENCE="429,200", TEST_RETRY_AFTER="not-a-date")
        self.run_script("author_info.sh", "42")
        self.assertEqual(self.sleeps(), ["2"])

    def test_long_retry_after_stops_without_early_retry(self):
        self.env.update(TEST_HTTP_STATUS="429", TEST_RETRY_AFTER="120")
        self.run_script("author_info.sh", "42", expected=1)
        self.assertEqual(self.request_count(), 1)
        self.assertEqual(self.sleeps(), [])

    def test_auth_errors_not_retried(self):
        for code in ("401", "403"):
            with self.subTest(code=code):
                self.env["TEST_HTTP_STATUS"] = code
                result = self.run_script("author_info.sh", "42", expected=1)
                self.assertIn("authentication or permission", json.loads(result.stderr)["error"])
        self.assertEqual(self.request_count(), 2)
        self.assertEqual(self.sleeps(), [])

    def test_network_failure_is_sanitized(self):
        self.env["TEST_NETWORK_FAIL"] = "1"
        result = self.run_script("author_info.sh", "42", expected=1)
        self.assertIn("network request failed", json.loads(result.stderr)["error"])
        self.assertEqual(result.stdout, "")
        self.assertEqual(self.request_count(), 1)

    def test_retries_can_be_disabled(self):
        self.env.update(S2_MAX_RETRIES="0", TEST_HTTP_STATUS="429")
        self.run_script("author_info.sh", "42", expected=1)
        self.assertEqual(self.request_count(), 1)

    def test_invalid_retry_configuration_fails_before_request(self):
        self.env["S2_MAX_RETRIES"] = "-1"
        result = self.run_script("author_info.sh", "42", expected=1)
        self.assertIn("integers", json.loads(result.stderr)["error"])
        self.assertFalse(Path(self.env["TEST_CURL_ARGS"]).exists())

    def test_real_curl_retry_and_header_delivery(self):
        from http.server import BaseHTTPRequestHandler, HTTPServer
        import threading
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.headers.get("x-api-key"))
                self.send_response(429 if len(requests) == 1 else 200)
                self.send_header("Retry-After", "0")
                self.end_headers()
                self.wfile.write(b'{"ok":true}' if len(requests) > 1 else b'{"error":"limited"}')

            def log_message(self, *args):
                pass

        server = HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        env = dict(self.env, PATH=os.environ["PATH"], S2_API_KEY="local-fixture-key", NO_PROXY="127.0.0.1",
                   no_proxy="127.0.0.1", TMPDIR=str(self.root))
        try:
            result = subprocess.run(
                ["bash", "-c", 'source "$1"; s2_request "$2" 5', "test",
                 str(self.install / "scripts/s2_request.sh"),
                 "http://127.0.0.1:" + str(server.server_port)],
                cwd=self.paper, env=env, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), '{"ok":true}\n200')
            self.assertEqual(requests, ["local-fixture-key", "local-fixture-key"])
            self.assertNotIn("local-fixture-key", result.stderr)
            self.assertEqual(list(self.root.glob("tmp.*")), [])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)

    def test_missing_arguments(self):
        for script in (self.install / "scripts").glob("*.sh"):
            if script.name in ("init.sh", "s2_request.sh"):
                continue
            with self.subTest(script=script.name):
                result = self.run_script(script.name, expected=1)
                self.assertIn("Usage:", result.stderr)


if __name__ == "__main__":
    unittest.main()
