# Minimal production-ready template for a Next.js app

## Introduction

I'm a full-stack developer and have been doing web development since around 2014. In recent years I've been focusing more on in-house projects, freelance work, and my own micro-products. A constant pain point is the lack of a convenient, ideally free, way to spin up yet another project for a task without getting bogged down in infrastructure.

Over several years I've brought a few things to a solid, reusable state:

- Automated deploy to a server (including blue/green);
- Issuing and renewing SSL certificates for the domain;
- A minimal metrics stack (Grafana, Prometheus, Loki, etc.) — optional, controlled by flags.

The result is two battle-tested boilerplates: Nest.js and Next.js. In this article I'm sharing the second one. To keep infrastructure simple, the template is built around a single stack: Next.js, auth, and database access within one application.

This kind of template may not be anything new, but if it saves someone a few hours on deploy and environment setup, I'll be glad.

## From idea to release

Most developers want to take an idea to a working product — a side project, a micro-product, an internal service. I'll speak from my own experience: everyone's context and goals are different.

A lot can be built today with AI and ready-made tutorials. Getting a product to a stable release without getting stuck on infrastructure is another story. That's why I published this standalone Next.js template: deploy, certificates, and optional metrics are already wired in. You can use it as a base and focus on your app logic.

You're free to do whatever you want with the template: it's open. The repo includes the essentials — auth, cookies, database, scripts, and workflows for your server.

## What's inside

The template is built for one scenario: one repo, one stack (Next.js + API routes + DB and sessions when needed). No separate infra “admin” layer — everything is driven by config and flags in GitHub Actions.

**Deploy and environments**

- Workflows for stage and prod (separate files under `.github/workflows/`), with shared logic in a reusable workflow.
- Support for “build on server” and “image from GHCR”; optionally blue/green (with some caveats).
- Deploy triggers on push to the right branch; only the containers you need are started on the server.

**Certificates and nginx**

- Let's Encrypt via certbot: initial issuance and renewal.
- Nginx as the single entry point: proxy to Next.js, and when metrics are enabled, a subpath for Grafana. The nginx config is generated from templates using the `METRICS_ENABLED` flag: when metrics are off, Grafana blocks are omitted, so nginx doesn't depend on the Grafana container.

**Optional parts**

- **Redis** — started only when `redis_enabled: true` in the workflow config.
- **Metrics (Grafana, Prometheus, Loki, Telegraf, Promtail, etc.)** — only when `metrics_enabled: true`. Both flags are off by default: only nginx and the app are always run.

So you can start with the minimum (app + nginx + certificates) and turn on cache and dashboards with a single change in `stage-deploy.yml` / `prod-deploy.yml`.

**Auth and database**

- The repo includes a minimal layer for auth and DB access within Next.js (API routes, cookies, sessions). If you need a separate backend, you can keep the same workflows and scripts and adapt the logic in `app/api/[...]/route` and deploy flags to your setup.

## Who might find this useful

Anyone who wants to get an idea to production quickly without diving deep into DevOps: one repo, clear flags, one server. And anyone already comfortable with Next.js who wants a ready-made base with deploy and optional metrics — with no extra services by default.

Repo: [nextjs-super-boilerplate](https://github.com/Fedorrychkov/nextjs-super-boilerplate). If this approach fits you, feel free to use the template as a base for your next project or a quick release; I’d appreciate a star and feedback. Please do open issues if you run into problems or find bugs in the core setup.
