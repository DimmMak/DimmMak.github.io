# Testing

This repo has Playwright smoke tests that run against the live site at https://dimmmak.github.io.

## Run tests locally

```bash
# One-time setup
npm ci
npx playwright install chromium

# Run all tests
npx playwright test

# Run in UI mode (great for debugging)
npx playwright test --ui

# Run with a visible browser (watch it click)
npx playwright test --headed

# Step through a single test
npx playwright test --debug
```

Reports land in `playwright-report/` (gitignored). Open the HTML report with:

```bash
npx playwright show-report
```

## CI (GitHub Actions)

The workflow lives at `.github/workflows/playwright.yml` and runs on:

- **After every successful `Build and Deploy`** — tests the freshly deployed site
- **Nightly at 09:00 UTC** — safety backstop
- **Manual dispatch** — click "Run workflow" on the Actions tab

If a run fails, the HTML report is uploaded as an artifact (retained 14 days).

## Adding tests

Put new spec files in `tests/`. Anything matching `*.spec.ts` gets picked up.

`baseURL` is set in `playwright.config.ts`, so you can write `page.goto('/')`
instead of the full URL.

## Tuning the sweet spot

- Tests hit a real live site, so they're slower than unit tests but catch real breakage
- If a test is flaky, prefer `expect(...).toBeVisible()` web-first assertions (auto-wait)
- Avoid `waitForTimeout` — use locators and web-first assertions instead
