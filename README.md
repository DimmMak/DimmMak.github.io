# dimmmak.github.io

**Source for [dimmmak.github.io](https://dimmmak.github.io).**

Plain markdown. Git-tracked. Hosted free forever on GitHub Pages via Jekyll.

## Philosophy

Matches every principle that guides my fleet:

- 🟢 **Plain text > proprietary** — every post is a `.md` file
- 🟢 **Owned + portable** — if GitHub dies, `git clone` and host anywhere
- 🟢 **Git-tracked edit history** — every change dated + diffable forever
- 🟢 **Auto-deploys on push** — same workflow as my skills
- 🟢 **50-year durable** — nothing proprietary, nothing SaaS-locked

## Structure

```
.
├── _config.yml        ← Jekyll config
├── _posts/            ← Blog posts (one markdown file per post)
├── index.md           ← Home page
├── about.md           ← About page
└── README.md          ← This file
```

## Write a new post

```bash
cat > _posts/$(date +%Y-%m-%d)-slug-here.md <<EOF
---
layout: post
title: "Post title"
date: $(date +%Y-%m-%d)
---

Content...
EOF

git add -A
git commit -m "post: title here"
git push
# Visit dimmmak.github.io in ~60 seconds — live.
```

## License

Content: CC BY 4.0. Code samples: MIT.
