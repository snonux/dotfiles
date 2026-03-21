---
name: gogios
description: Deploy the Gogios project using the established mage and rex workflow. Use when the user asks to build, deploy, install, or update Gogios, or mentions gogios deployment steps.
---

# Gogios

## When to Use

Use this skill when working on Gogios deployment tasks, especially when the request involves:
- Building Gogios artifacts for OpenBSD
- Deploying Gogios to an OpenBSD target
- Running the frontend install workflow via `rex`
- Repeating the standard "build then install" deployment sequence

## Instructions

Follow this workflow in order:

1. Build and deploy Gogios for OpenBSD from the project context:
   - Run: `mage buildOpenbsd deployOpenbsd`

2. Move to the frontend repo directory:
   - Change directory to: `~/git/conf/frontends`

3. Run the Gogios install task:
   - Run: `rex gogios_install`

## Notes

- Keep this sequence ordered: build/deploy first, install second.
- If any command fails, stop and report the failing command with the error output before retrying.
