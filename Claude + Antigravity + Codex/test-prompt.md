# Claude + Antigravity + Codex test prompt

Paste this prompt, unchanged, into a fresh Claude Code session in an empty folder with Claude + Antigravity + Codex installed.

```
Build a small multi-page landing site for a fictional product, "Driftwood", a focus-music app.

SPEC
- Plain HTML, CSS and vanilla JavaScript. No framework, no external URLs, fonts, images or CDNs.
- Files: styles.css, index.html, features.html, pricing.html, faq.html, app.js.
- styles.css is the shared design system everything else uses: color tokens as CSS variables (warm sand, driftwood brown, deep sea blue), system font stack, type scale, spacing scale, container (1000px max), nav, footer, card grid, buttons, form/toggle styles, responsive down to 360px, visible focus styles.
- index.html: hero with headline, subline and CTA to pricing.html, a three-step "how it works" row, and a short testimonial strip.
- features.html: six feature cards (sound mixes, focus timer, offline mode, sleep sounds, playlists, stats) and a comparison table.
- pricing.html: Free, Pro and Team plan cards with a monthly/yearly toggle that updates the prices (yearly saves 20%).
- faq.html: eight questions as an accordion that opens one at a time and works with the keyboard.
- app.js: the pricing toggle and the FAQ accordion, loaded only by the pages that need it.
- Every page: <title>, lang attribute, viewport meta, stylesheet link, the same nav (current page highlighted) and footer.

SELF-CHECK
Before finishing, check that all six files exist, every href and src points to a real file, every page uses styles.css, list any accessibility issues (missing alt, unlabeled controls, heading order, low contrast, no focus style), and find any leftover placeholder text (TODO, lorem ipsum, console.log, http:// or https://). Fix everything you find, then re-check.

TIMING
As your very first action, run `date +%s` and remember the number. As your very last action, run `date +%s` again, subtract, and print "Elapsed: Xm Ys".

FINISH
Print: files created, whether the self-check passed, issues found and fixed, and one line on anything not done.
```
