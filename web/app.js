/* =========================================================================
   Cascade — WOW money-flow visualization engine
   Vanilla JS, no bundler. Renders the A->B->C dependency tree as SVG and
   animates ONE invoke sending a payment particle UP the tree, splitting at
   each node, with creator balances ticking to their REAL mainnet deltas.

   Motion is compositor-friendly (transform/opacity + rAF only) and honors
   prefers-reduced-motion (snaps to final state, no particle flight).
   ========================================================================= */
(() => {
  "use strict";

  /* ---------- constants (no magic numbers buried in logic) ---------- */
  const WEI_PER_PROS = 10n ** 18n;
  const PROS_DECIMALS = 6;
  const SVG_NS = "http://www.w3.org/2000/svg";

  // viewBox is 720 x 560; nodes are stacked on the vertical centre line so the
  // particle visibly RISES up the tree. Invoked node (C) sits at the bottom
  // (where the payer's money enters); the deepest leaf (A) sits at the top.
  const CENTER_X = 360;
  const NODE_W = 360;
  const NODE_H = 96;
  const NODE_CYS = [470, 290, 110]; // index 0 = first node in data (C), last = A
  const PARTICLE_START_Y = 552;     // just below the bottom node
  const PARTICLE_R = 11;

  const DUR_TRAVEL = 760;  // ms per edge segment
  const DUR_CREDIT = 560;  // ms to tick a balance at a node
  const DUR_ENTRY = 520;   // ms for the payer -> bottom-node entry

  const REDUCED_MOTION =
    window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- snapshot loading: fetch first, inline fallback ---------- */
  // Prefer fetch('./data.json'); on ANY failure (notably file:// CORS) fall
  // back to parsing the inline <script id="snapshot"> block in index.html.
  function readInlineSnapshot() {
    const el = document.getElementById("snapshot");
    if (!el) throw new Error("inline #snapshot block missing");
    return JSON.parse(el.textContent);
  }

  async function loadSnapshot() {
    try {
      const res = await fetch("./data.json", { cache: "no-store" });
      if (!res.ok) throw new Error("HTTP " + res.status);
      return await res.json();
    } catch (err) {
      // file:// or offline: graceful fallback to the committed inline snapshot.
      console.info("[cascade] data.json fetch unavailable, using inline snapshot:", err.message);
      return readInlineSnapshot();
    }
  }

  /* ---------- formatting helpers ---------- */
  function truncAddr(addr) {
    if (!addr || addr.length < 12) return addr || "";
    return addr.slice(0, 6) + "…" + addr.slice(-4);
  }

  // Exact wei -> "0.000500 PROS" using BigInt (no float precision loss on 1e15).
  function formatProsFromWei(wei) {
    const w = typeof wei === "bigint" ? wei : BigInt(wei);
    const whole = w / WEI_PER_PROS;
    const frac = (w % WEI_PER_PROS).toString().padStart(18, "0").slice(0, PROS_DECIMALS);
    return `${whole.toString()}.${frac} PROS`;
  }

  /* ---------- tiny SVG builder ---------- */
  function svg(tag, attrs, parent) {
    const el = document.createElementNS(SVG_NS, tag);
    for (const k in attrs) el.setAttribute(k, attrs[k]);
    if (parent) parent.appendChild(el);
    return el;
  }

  /* ---------- rAF primitives (return Promises so steps can be awaited) ---------- */
  const easeOutExpo = (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t));

  function tween(duration, onFrame, isAlive) {
    return new Promise((resolve) => {
      if (REDUCED_MOTION || duration <= 0) {
        onFrame(1);
        resolve();
        return;
      }
      const start = performance.now();
      function step(now) {
        if (!isAlive()) return resolve(); // run was superseded by a replay
        const t = Math.min(1, (now - start) / duration);
        onFrame(easeOutExpo(t));
        if (t < 1) requestAnimationFrame(step);
        else resolve();
      }
      requestAnimationFrame(step);
    });
  }

  /* =========================================================================
     TreeViz — generic engine reused by BOTH demos (royalty + 4337 batch).
     config: {
       svgEl, balancesListEl, sigmaValEl, playBtn, playLabelEl,
       nodes,           // data.tree (ordered C, B, A)
       totalWei,        // string, for the sigma readout
       sigmaMode,       // 'value' -> tick PROS sigma; 'static' -> leave as-is
       creditLabel,     // e.g. 'Play the split' / 'Replay'
       passes           // 1 (royalty) or 2 (batch); balances accumulate per pass
     }
     ========================================================================= */
  class TreeViz {
    constructor(config) {
      this.cfg = config;
      this.runId = 0;            // bumps on every play() to cancel stale frames
      this.nodeEls = new Map();  // id -> { box, balText, rowAmount, row }
      this.edgeFlowEls = [];     // edge-flow segments, bottom->top
      this._render();
      this._reset();
      this.cfg.playBtn.addEventListener("click", () => this.play());
    }

    /* build the SVG tree + the balances panel rows */
    _render() {
      const { svgEl, balancesListEl, nodes } = this.cfg;
      svgEl.innerHTML = "";
      balancesListEl.innerHTML = "";

      // base edges first (behind nodes): connect consecutive stacked nodes
      for (let i = 0; i < nodes.length - 1; i++) {
        const yLow = NODE_CYS[i] - NODE_H / 2;       // top of lower node
        const yHigh = NODE_CYS[i + 1] + NODE_H / 2;  // bottom of upper node
        svg("line", { class: "edge", x1: CENTER_X, y1: yLow, x2: CENTER_X, y2: yHigh }, svgEl);
        const flow = svg("line", { class: "edge-flow", x1: CENTER_X, y1: yLow, x2: CENTER_X, y2: yHigh }, svgEl);
        this.edgeFlowEls.push(flow);
      }

      // nodes
      nodes.forEach((n, i) => {
        const cy = NODE_CYS[i];
        const x = CENTER_X - NODE_W / 2;
        const y = cy - NODE_H / 2;
        const g = svg("g", { class: `node node-${n.role}` }, svgEl);

        const box = svg("rect", {
          class: "node-box", x, y, width: NODE_W, height: NODE_H, rx: 12
        }, g);

        svg("text", { class: "node-label", x: x + 30, y: cy + 12, "font-size": 38 }, g)
          .textContent = n.label;

        const tag = svg("text", { class: "node-tag", x: x + 66, y: cy - 14, "font-size": 13 }, g);
        tag.textContent = `skill #${n.id} · ${roleWord(n.role)}`;

        svg("text", { class: "node-addr", x: x + 66, y: cy + 8, "font-size": 13 }, g)
          .textContent = truncAddr(n.creator);

        svg("text", { class: "node-role", x: x + 66, y: cy + 28, "font-size": 11 }, g)
          .textContent = depWord(n);

        const balText = svg("text", {
          class: "node-bal", x: x + NODE_W - 22, y: cy + 8, "font-size": 22, "text-anchor": "end"
        }, g);
        balText.textContent = "0.000000";

        // a "splat" ring that pops when this node is credited
        svg("circle", { class: "splat", cx: CENTER_X, cy, r: 14 }, g);

        this.nodeEls.set(n.id, { box, balText, group: g, cy });

        // balances-panel row
        const li = document.createElement("li");
        li.className = "balance-row";
        li.innerHTML = `
          <span class="bal-chip" data-role="${n.role}">${n.label}</span>
          <span class="bal-meta">
            <span class="bal-addr">${truncAddr(n.creator)}</span><br />
            <span class="bal-share">skill #${n.id} · ${n.sharePct}% of price</span>
          </span>
          <span class="bal-amount mono">0.000000 PROS</span>`;
        balancesListEl.appendChild(li);
        const rec = this.nodeEls.get(n.id);
        rec.row = li;
        rec.rowAmount = li.querySelector(".bal-amount");
      });

      // the travelling money particle (drawn last = on top)
      this.particle = svg("circle", {
        class: "particle", cx: CENTER_X, cy: PARTICLE_START_Y, r: PARTICLE_R
      }, svgEl);
    }

    _reset() {
      this.runId++; // cancel any in-flight animation
      for (const rec of this.nodeEls.values()) {
        rec.box.classList.remove("is-credited");
        rec.row.classList.remove("is-credited");
        rec.balText.textContent = "0.000000";
        rec.rowAmount.textContent = "0.000000 PROS";
      }
      this.edgeFlowEls.forEach((e) => e.classList.remove("is-lit"));
      this.particle.classList.remove("is-visible");
      this.particle.setAttribute("cy", PARTICLE_START_Y);
      if (this.cfg.sigmaMode === "value" && this.cfg.sigmaValEl) {
        this.cfg.sigmaValEl.textContent = "0.000000 PROS";
      }
      this._setPlaying(false);
    }

    _setPlaying(on) {
      const { playBtn, playLabelEl } = this.cfg;
      playBtn.classList.toggle("is-playing", on);
      playBtn.disabled = on;
      if (playLabelEl) playLabelEl.textContent = on ? "Playing…" : this.cfg.creditLabel;
    }

    _moveParticle(fromY, toY, alive) {
      return tween(DUR_TRAVEL, (p) => {
        this.particle.setAttribute("cy", fromY + (toY - fromY) * p);
      }, alive);
    }

    _tickSigma() {
      if (this.cfg.sigmaMode !== "value" || !this.cfg.sigmaValEl) return;
      let total = 0n;
      for (const n of this.cfg.nodes) {
        const rec = this.nodeEls.get(n.id);
        total += rec._curWei || 0n;
      }
      this.cfg.sigmaValEl.textContent = formatProsFromWei(total);
    }

    /* the headline sequence: particle rises C -> B -> A, splitting each node */
    async play() {
      this._reset();
      const myRun = ++this.runId;
      const alive = () => this.runId === myRun;
      this._setPlaying(true);

      const nodes = this.cfg.nodes;            // [C, B, A] bottom -> top
      const passes = this.cfg.passes || 1;

      // running per-node accumulated wei (so multi-pass batch keeps summing)
      const acc = new Map(nodes.map((n) => [n.id, 0n]));

      if (REDUCED_MOTION) {
        // snap straight to the final state, no particle flight
        for (let pass = 0; pass < passes; pass++) {
          nodes.forEach((n) => acc.set(n.id, acc.get(n.id) + BigInt(n.deltaWei)));
        }
        this._snapTo(acc);
        this._setPlaying(false);
        return;
      }

      this.particle.classList.add("is-visible");

      for (let pass = 0; pass < passes; pass++) {
        // payer -> bottom node entry
        this.particle.setAttribute("cy", PARTICLE_START_Y);
        await tween(DUR_ENTRY, (p) => {
          this.particle.setAttribute("cy", PARTICLE_START_Y + (NODE_CYS[0] - PARTICLE_START_Y) * p);
        }, alive);
        if (!alive()) return;

        for (let i = 0; i < nodes.length; i++) {
          const n = nodes[i];
          const rec = this.nodeEls.get(n.id);
          // light the edge we just travelled (none before the first node)
          if (i > 0) this.edgeFlowEls[i - 1].classList.add("is-lit");

          // split off this creator's share -> balance ticks up
          const start = acc.get(n.id);
          const end = start + BigInt(n.deltaWei);
          this._splat(rec);
          await this._creditWithTrack(n, rec, start, end, acc, alive);
          if (!alive()) return;

          // continue up to the next node
          if (i < nodes.length - 1) {
            await this._moveParticle(NODE_CYS[i], NODE_CYS[i + 1], alive);
            if (!alive()) return;
          }
        }
      }

      // fade the particle out at the top (leaf fully paid)
      await tween(DUR_CREDIT, (p) => {
        this.particle.style.opacity = String(1 - p);
      }, alive);
      this.particle.classList.remove("is-visible");
      this.particle.style.opacity = "";
      this._setPlaying(false);
    }

    // credit a node while tracking accumulated wei for an accurate sigma
    async _creditWithTrack(node, rec, startWei, endWei, acc, alive) {
      const span = endWei - startWei;
      await tween(DUR_CREDIT, (p) => {
        const permille = BigInt(Math.round(p * 1000));
        const cur = startWei + (span * permille) / 1000n;
        rec._curWei = cur;
        rec.balText.textContent = formatProsFromWei(cur).replace(" PROS", "");
        rec.rowAmount.textContent = formatProsFromWei(cur);
        this._tickSigma();
      }, alive);
      rec._curWei = endWei;
      acc.set(node.id, endWei);
      this._tickSigma();
    }

    _splat(rec) {
      const splat = rec.group.querySelector(".splat");
      if (!splat || REDUCED_MOTION) return;
      splat.style.transition = "none";
      splat.setAttribute("opacity", "0.9");
      splat.setAttribute("r", "14");
      // expand + fade using rAF (opacity + r only)
      const start = performance.now();
      const grow = (now) => {
        const t = Math.min(1, (now - start) / 480);
        splat.setAttribute("r", String(14 + 30 * t));
        splat.setAttribute("opacity", String(0.9 * (1 - t)));
        if (t < 1) requestAnimationFrame(grow);
        else splat.setAttribute("opacity", "0");
      };
      requestAnimationFrame(grow);
    }

    _snapTo(acc) {
      for (const n of this.cfg.nodes) {
        const rec = this.nodeEls.get(n.id);
        const w = acc.get(n.id);
        rec._curWei = w;
        rec.box.classList.add("is-credited");
        rec.row.classList.add("is-credited");
        rec.balText.textContent = formatProsFromWei(w).replace(" PROS", "");
        rec.rowAmount.textContent = formatProsFromWei(w);
      }
      this.edgeFlowEls.forEach((e) => e.classList.add("is-lit"));
      this._tickSigma();
    }
  }

  function roleWord(role) {
    return role === "invoked" ? "invoked" : role === "branch" ? "dependency" : "leaf";
  }
  function depWord(n) {
    if (n.role === "invoked") return `price 0.001 PROS · keeps ${n.sharePct}%`;
    if (n.role === "branch") return `dep @ ${(n.depBps / 100).toFixed(0)}% · earns ${n.sharePct}%`;
    return `deepest leaf · earns ${n.sharePct}%`;
  }

  /* ---------- demo tab switching ---------- */
  function wireTabs() {
    const tabs = document.querySelectorAll(".switch-btn");
    const panels = {
      royalty: document.getElementById("view-royalty"),
      batch: document.getElementById("view-batch")
    };
    tabs.forEach((tab) => {
      tab.addEventListener("click", () => {
        const view = tab.dataset.view;
        tabs.forEach((t) => {
          const on = t === tab;
          t.classList.toggle("is-active", on);
          t.setAttribute("aria-pressed", String(on));
        });
        Object.entries(panels).forEach(([k, el]) => {
          if (!el) return;
          const on = k === view;
          el.classList.toggle("is-active", on);
          el.hidden = !on;
        });
      });
    });
  }

  /* ---------- boot ---------- */
  async function boot() {
    const data = await loadSnapshot();
    window.__cascadeData = data; // exposed for Task 3 batch wiring

    wireTabs();

    // Royalty split (MAIN-02): one invoke, single pass, deltas tick the sigma.
    const royalty = new TreeViz({
      svgEl: document.getElementById("svg-royalty"),
      balancesListEl: document.getElementById("balances-royalty"),
      sigmaValEl: document.getElementById("sigma-royalty-val"),
      playBtn: document.getElementById("play-royalty"),
      playLabelEl: document.querySelector("#play-royalty .play-label"),
      nodes: data.tree,
      totalWei: data.royaltyDemo.sumWei,
      sigmaMode: "value",
      creditLabel: "Replay the split",
      passes: 1
    });
    window.__cascadeRoyalty = royalty;

    // wire the royalty tx-proof link from the snapshot
    const txRoyalty = document.getElementById("tx-royalty");
    if (txRoyalty) txRoyalty.href = data.network.explorer + "tx/" + data.royaltyDemo.invokeTxHash;

    // Task 3 attaches the batch viz + AA grid via window.__cascadeData.
    if (typeof window.__cascadeInitBatch === "function") {
      window.__cascadeInitBatch(data, TreeViz);
    }
    // expose the engine so the batch init (same file, Task 3) can reuse it
    window.__cascadeTreeViz = TreeViz;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
