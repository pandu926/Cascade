# Cascade — DoraHacks Submission Checklist

> A turnkey checklist for the **human** to push the repo public, record the demo video,
> and submit Cascade to the **Skill-to-Agent Dual Cascade Hackathon (Pharos)** on DoraHacks.
> Tick each box as you go. **Deadline: 2026-06-15 15:59** (earliest stated deadline — the
> hackathon page is inconsistent and also says June 16; submit by the earliest to be safe).

---

## 0. Pre-push safety (do this FIRST)

- [ ] Confirm no secrets are staged: `git status` shows **no** `.env`, no private keys.
- [ ] Confirm `.env` is gitignored: `grep -n '^.env$' .gitignore` prints a match (it does).
- [ ] Sanity scan for an accidental key: `git grep -nE '0x[a-fA-F0-9]{64}' -- . ':!MAINNET_RESULT.md' ':!*.md'` returns nothing unexpected (the only long hexes in docs are addresses/tx hashes, which are public).
- [ ] Confirm the working tree is clean and committed: `git status` is clean.

## 1. Push to a public remote

The repo currently has **NO git remote**. Create a public repo on GitHub/GitLab/Bitbucket,
then wire it up and push. Replace `<URL>` with your new repo's URL.

- [ ] Create a new **public** repository on GitHub (or GitLab / Bitbucket).
- [ ] Add the remote and push the current branch:

  ```bash
  # current branch is `master`
  git remote add origin <URL>          # e.g. https://github.com/<you>/cascade.git
  git push -u origin master
  ```

  If the host's default branch is `main` and you prefer that:

  ```bash
  git branch -M main
  git remote add origin <URL>
  git push -u origin main
  ```

- [ ] Open the pushed repo in a browser and confirm `README.md` renders and all links work.

## 2. Record + upload the demo video

- [ ] Record the demo following [`docs/DEMO_VIDEO_SCRIPT.md`](docs/DEMO_VIDEO_SCRIPT.md)
      (≤ ~3 min): open the viz → one invoke fans to three creators (Σ 0.001 PROS) → show
      the real pharosscan invoke tx → the 4337 batch → close on the verified contract.
- [ ] Upload it (YouTube / Loom / Vimeo or attach to the BUIDL) and copy the public link.
- [ ] Paste that video link into the **Demo link** field below.

## 3. Visually confirm the pharosscan "Verified" checkmark (carried-over Phase 5 residual)

- [ ] Open the Cascade contract **Code** tab and confirm the green **"Verified"** checkmark
      is shown:
      https://www.pharosscan.xyz/address/0x31bE4C6B5711913D818e377ebd809d4397FF3c84
      — the read command-API cannot confirm verification programmatically, so this is a
      manual visual check (see the residual note in [`MAINNET_RESULT.md`](MAINNET_RESULT.md)
      and [`SECURITY.md`](SECURITY.md)).

## 4. DoraHacks form fields (pre-filled)

Submit as a **BUIDL** on DoraHacks: https://dorahacks.io/hackathon/pharos-phase1/detail
Required by the hackathon page: **GitHub/GitLab/Bitbucket link** and **Demo Video** (both mandatory).

- [ ] **Skill / Project name:** `Cascade`
- [ ] **Track:** Skill Hackathon (Phase 1 — 20,000 PROS, 40 winners)
- [ ] **Short description:**
      *Recursive skill royalties on Pharos. Like npm, but every package earns a cut every
      time it's used downstream — one `invoke` pays every creator up the dependency tree,
      proportionally, trustlessly, in a single transaction. Live and source-verified on
      Pharos mainnet, with an ERC-4337 account-abstraction layer for batched invokes.*
- [ ] **GitHub link:** `<URL from step 1>`  *(REQUIRED — fill after pushing)*
- [ ] **Demo link:** `<video URL from step 2>` + live visualization `web/index.html` in the repo  *(REQUIRED)*
- [ ] **Instructions / how to use:** See the repo [`README.md`](README.md) **Quickstart** —
      install Foundry (`foundryup`), `forge test` (41 pass), `cp .env.example .env` and set
      `PRIVATE_KEY`, then run register / invoke / claim per [`references/`](references/);
      open [`web/index.html`](web/index.html) for the visualization. Full Agent-Skill usage
      in [`SKILL.md`](SKILL.md).
- [ ] **Supported framework:** Anthropic Agent Skills + Foundry (`forge` / `cast`).
- [ ] **Dependencies / notes:** Foundry CLI (`forge`, `cast`) required; targets Pharos
      atlantic-testnet (default, chainId 688689) or mainnet (chainId 1672). Live
      source-verified mainnet contract: `0x31bE4C6B5711913D818e377ebd809d4397FF3c84`.
      Royalty demo tx `0x5ba20c87…dd3b1564`; 4337 batch tx `0x1f3cec93…4375f90`. Honest
      scope: fuzz/invariant-tested + slither-clean, **not** an independent audit (see
      [`SECURITY.md`](SECURITY.md)).

## 5. Submit

- [ ] Double-check the GitHub link and Demo video link are both filled (both are **Required**).
- [ ] Submit the BUIDL on DoraHacks **before 2026-06-15 15:59**.
- [ ] Save a screenshot / confirmation of the submitted BUIDL.

---

### Quick reference — verified mainnet artifacts

| What | Value |
|------|-------|
| Cascade (verified) | `0x31bE4C6B5711913D818e377ebd809d4397FF3c84` |
| Royalty invoke tx | `0x5ba20c8771787ff4bc4ea5c938fa32a394f4c1103318b7cfe0039f19dd3b1564` |
| 4337 handleOps tx | `0x1f3cec937acec167db716adf10be50bf135ac08f9ba3f02974cc0ee524375f90` |
| Explorer | https://www.pharosscan.xyz/ |
| Deadline | 2026-06-15 15:59 |
