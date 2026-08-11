# Uttarakhand Krishi Roadmap Preparation

The front page for the **Government of Uttarakhand's** Krishi (Agriculture) Roadmap — a 20-year pragmatic guide developed across 13 districts by 21 committees on a 2-month timeline.

Built as a clean, single-page landing site: no frameworks, no build step, just HTML, CSS, and a little JavaScript.

## Highlights

- **Government of Uttarakhand** branding with the state emblem in the header.
- Animated hero — "Uttarakhand Krishi Roadmap Preparation" — on a warm-to-navy gradient with a subtle grain texture.
- Key facts at a glance: **21 committees · 13 districts · 20-year plan · 2-month timeline**.
- A left-side section navigator (1–21) that collapses into a scrollable bottom bar on smaller screens.
- Fully responsive and mobile-first — works from phones to large desktops.
- Tool-neutral and dependency-free (only Google Fonts is loaded from the web).

## How to view

Open `index.html` directly in any modern browser. That is the entire runtime.

For a quick local preview server (optional):

```
python3 -m http.server 8000
# then visit http://localhost:8000
```

## Project structure

```
.
├── index.html     # the entire page (HTML + CSS + JS in one file)
├── UK-logo.png    # Government of Uttarakhand emblem used in the header
└── README.md      # this file
```

## Deployment

Because it is a static site, it can be hosted anywhere that serves files — GitHub Pages, Netlify, Cloudflare Pages, or any web server. No server-side code is required.

---

*A demonstration front page prepared for the Uttarakhand Krishi Roadmap initiative.*
