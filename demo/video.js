/* ============================================================
   Cascade Demo Video — GSAP Animation Engine
   Master timeline: 3 scenes, ~50s total (adjustable via SPEED)
   After Effects quality: elastic easing, MotionPath, stagger,
   stroke-draw, number-tick, typewriter, layered composition.
   ============================================================ */
(() => {
  "use strict";

  gsap.registerPlugin(MotionPathPlugin, TextPlugin);

  const SPEED = 1;
  const $ = (s) => document.querySelector(s);
  const $$ = (s) => [...document.querySelectorAll(s)];

  const DATA = {
    cascade: "0x31bE4C6B5711913D818e377ebd809d4397FF3c84",
    invokeTx: "0x5ba20c8771787ff4bc4ea5c938fa32a394f4c1103318b7cfe0039f19dd3b1564",
    explorerUrl: "pharosscan.xyz/tx/0x5ba20c87...dd3b1564",
    creators: [
      { id: "A", addr: "0x7ca0...56b8", delta: 0.0002, label: "SKILL A", role: "leaf" },
      { id: "B", addr: "0xD79F...796b", delta: 0.0003, label: "SKILL B", role: "dep of C" },
      { id: "C", addr: "0xECe4...12ef", delta: 0.0005, label: "SKILL C", role: "invoked" },
    ],
    price: 0.001,
  };

  /* ========== MASTER TIMELINE ========== */
  const tl = gsap.timeline({ paused: true, onUpdate: updateProgress, onComplete: onEnd });

  /* ---------- SCENE 1: THE HOOK ---------- */
  tl.addLabel("scene1", 0);

  // Bg grid fade in
  tl.to(".bg-grid", { opacity: 0.6, scale: 1, duration: 1.5 / SPEED, ease: "power2.out" }, "scene1");

  // Logo entrance
  tl.to(".logo", { opacity: 1, duration: 0.5 / SPEED }, "scene1+=0.3");
  tl.fromTo(".logo-svg polygon, .logo-svg path",
    { strokeDashoffset: 200 },
    { strokeDashoffset: 0, duration: 1.2 / SPEED, stagger: 0.15, ease: "power3.inOut" },
    "scene1+=0.5"
  );
  tl.fromTo(".logo-svg circle",
    { scale: 0, transformOrigin: "center" },
    { scale: 1, duration: 0.4 / SPEED, stagger: 0.1, ease: "back.out(2)" },
    "scene1+=1.2"
  );

  // Logo text chars
  tl.to("#logoText", { opacity: 1, duration: 0.01 }, "scene1+=1.5");
  tl.from("#logoText", { y: 30, opacity: 0, duration: 0.8 / SPEED, ease: "back.out(1.7)" }, "scene1+=1.5");
  tl.to(".logo-sub", { opacity: 1, y: 0, duration: 0.6 / SPEED, ease: "power2.out" }, "scene1+=2.0");

  // Logo shrinks to top-left corner
  tl.to(".logo", {
    scale: 0.35, x: -680, y: -380, duration: 1 / SPEED, ease: "power3.inOut"
  }, "scene1+=3.5");

  // Tree appears
  tl.to(".tree", { opacity: 1, duration: 0.3 / SPEED }, "scene1+=4.0");
  tl.to("#scene1", { opacity: 1, duration: 0.01 }, "scene1");

  // Nodes pop in (bottom to top: C, B, A)
  tl.to(".node-c", { scale: 1, opacity: 1, duration: 0.6 / SPEED, ease: "elastic.out(1, 0.5)", clearProps: "transform" }, "scene1+=4.2");
  tl.to(".node-b", { scale: 1, opacity: 1, duration: 0.6 / SPEED, ease: "elastic.out(1, 0.5)", clearProps: "transform" }, "scene1+=4.6");
  tl.to(".node-a", { scale: 1, opacity: 1, duration: 0.6 / SPEED, ease: "elastic.out(1, 0.5)", clearProps: "transform" }, "scene1+=5.0");

  // Edges draw
  tl.to("#edgeCB", { strokeDashoffset: 0, duration: 0.8 / SPEED, ease: "power2.inOut" }, "scene1+=5.4");
  tl.to("#edgeBA", { strokeDashoffset: 0, duration: 0.8 / SPEED, ease: "power2.inOut" }, "scene1+=5.8");
  tl.to(".edge-label", { opacity: 1, duration: 0.4 / SPEED, stagger: 0.2 }, "scene1+=6.2");

  // Particle spawns
  tl.to("#particle", { opacity: 1, scale: 1, duration: 0.4 / SPEED, ease: "back.out(2)" }, "scene1+=7.0");

  // Particle travels C → B (using top property animation since MotionPath needs careful SVG path)
  tl.to("#particle", { top: 500, duration: 1 / SPEED, ease: "power2.inOut" }, "scene1+=7.5");

  // At B: balance ticks + particle split
  tl.to("#particleSplit", { opacity: 1, scale: 1, top: 500, duration: 0.3 / SPEED, ease: "back.out(1.5)" }, "scene1+=8.3");
  tl.to({ val: 0 }, {
    val: DATA.creators[1].delta, duration: 0.8 / SPEED, ease: "none",
    onUpdate() { $("#balB").textContent = this.targets()[0].val.toFixed(4); }
  }, "scene1+=8.5");

  // Particle continues B → A
  tl.to("#particle", { top: 320, duration: 1 / SPEED, ease: "power2.inOut" }, "scene1+=8.8");

  // A balance ticks
  tl.to({ val: 0 }, {
    val: DATA.creators[0].delta, duration: 0.8 / SPEED, ease: "none",
    onUpdate() { $("#balA").textContent = this.targets()[0].val.toFixed(4); }
  }, "scene1+=9.5");

  // C balance ticks (remainder — simultaneously)
  tl.to({ val: 0 }, {
    val: DATA.creators[2].delta, duration: 0.8 / SPEED, ease: "none",
    onUpdate() { $("#balC").textContent = this.targets()[0].val.toFixed(4); }
  }, "scene1+=9.5");

  // Gold flash on counters
  tl.fromTo(".node-balance", { color: "#fff" }, { color: "#f0b90b", duration: 0.5 / SPEED, ease: "power1.out" }, "scene1+=10.5");

  // Conservation text
  tl.to("#conservation", { opacity: 1, duration: 0.6 / SPEED, ease: "power2.out" }, "scene1+=11.0");

  // Hold
  tl.to({}, { duration: 2 / SPEED }, "scene1+=11.8");

  /* ---------- SCENE 2: THE PROOF ---------- */
  tl.addLabel("scene2", ">");

  // Scene 1 fades, Scene 2 appears
  tl.to("#scene1", { opacity: 0, duration: 0.8 / SPEED, ease: "power2.inOut" }, "scene2");
  tl.to("#scene2", { opacity: 1, duration: 0.8 / SPEED, ease: "power2.inOut" }, "scene2+=0.3");

  // Explorer slides in
  tl.to(".proof-right", { opacity: 1, x: 0, duration: 0.8 / SPEED, ease: "power3.out" }, "scene2+=0.8");

  // URL typewriter
  tl.to("#explorerUrl", { text: { value: DATA.explorerUrl }, duration: 1.5 / SPEED, ease: "none" }, "scene2+=1.5");

  // Title + status
  tl.to(".explorer-title", { opacity: 1, duration: 0.4 / SPEED }, "scene2+=3.0");
  tl.to(".status-badge", { scale: 1, duration: 0.4 / SPEED, ease: "back.out(1.7)" }, "scene2+=3.4");

  // Tx hash
  tl.to(".tx-row", { opacity: 1, duration: 0.3 / SPEED }, "scene2+=3.8");
  tl.to("#txHashValue", { text: { value: DATA.invokeTx.slice(0, 20) + "..." + DATA.invokeTx.slice(-8) }, duration: 1.2 / SPEED, ease: "none" }, "scene2+=3.8");

  // Events title
  tl.to(".events-title", { opacity: 1, duration: 0.3 / SPEED }, "scene2+=5.2");

  // Event rows stagger in
  tl.to(".event-row", {
    opacity: 1, y: 0, duration: 0.5 / SPEED, stagger: 0.35 / SPEED, ease: "power2.out"
  }, "scene2+=5.6");

  // Conservation line
  tl.to(".conservation-line", { opacity: 1, duration: 0.5 / SPEED, ease: "power2.out" }, "scene2+=7.8");

  // Verified badge
  tl.to(".verified-badge", { opacity: 1, y: 0, duration: 0.5 / SPEED, ease: "back.out(1.5)" }, "scene2+=8.5");
  tl.to(".verify-ring", { scale: 1, duration: 0.5 / SPEED, ease: "elastic.out(1, 0.6)", transformOrigin: "center" }, "scene2+=8.8");
  tl.to(".check-path", { strokeDashoffset: 0, duration: 0.6 / SPEED, ease: "power3.inOut" }, "scene2+=9.2");
  tl.to("#verifiedText", { opacity: 1, duration: 0.4 / SPEED }, "scene2+=9.8");

  // Hold
  tl.to({}, { duration: 2 / SPEED }, "scene2+=10.5");

  /* ---------- SCENE 3: THE VISION ---------- */
  tl.addLabel("scene3", ">");

  // Scene 2 fades
  tl.to("#scene2", { opacity: 0, duration: 0.8 / SPEED, ease: "power2.inOut" }, "scene3");
  tl.to("#scene3", { opacity: 1, duration: 0.8 / SPEED, ease: "power2.inOut" }, "scene3+=0.3");

  // Expanded tree enters
  tl.to(".vision-tree", { opacity: 1, scale: 1, duration: 0.8 / SPEED, ease: "power2.out" }, "scene3+=0.8");

  // Nodes stagger in
  tl.fromTo(".v-node",
    { opacity: 0, scale: 0 },
    { opacity: 1, scale: 1, duration: 0.5 / SPEED, stagger: { amount: 1, from: "center" }, ease: "elastic.out(1, 0.6)", transformOrigin: "center" },
    "scene3+=1.2"
  );

  // Edges draw
  tl.to(".v-edge", { strokeDashoffset: 0, duration: 0.8 / SPEED, stagger: 0.15, ease: "power2.inOut" }, "scene3+=2.5");

  // Agents fade in
  tl.to(".agent", { opacity: 1, duration: 0.5 / SPEED, stagger: 0.3, ease: "power2.out" }, "scene3+=3.8");

  // Agent pulse (infinite)
  tl.to(".agent", { scale: 1.08, duration: 0.8, repeat: -1, yoyo: true, ease: "sine.inOut" }, "scene3+=4.5");

  // Dim tree for text overlay
  tl.to(".vision-tree, .agent", { opacity: 0.25, duration: 0.8 / SPEED, ease: "power2.inOut" }, "scene3+=6.0");

  // Vision text
  tl.to(".vision-text", { opacity: 1, duration: 0.5 / SPEED }, "scene3+=6.5");
  tl.from("#visionSub", { y: 20, opacity: 0, duration: 0.6 / SPEED, ease: "power2.out" }, "scene3+=6.8");
  tl.from("#visionHeadline", { y: 30, opacity: 0, duration: 0.8 / SPEED, ease: "back.out(1.4)" }, "scene3+=7.2");
  tl.from("#visionDesc", { y: 15, opacity: 0, duration: 0.5 / SPEED, ease: "power2.out" }, "scene3+=8.0");
  tl.from("#visionDesc2", { y: 15, opacity: 0, duration: 0.5 / SPEED, ease: "power2.out" }, "scene3+=8.5");

  // Pharos badge
  tl.to("#pharosBadge", { opacity: 1, y: 0, duration: 0.6 / SPEED, ease: "back.out(1.5)" }, "scene3+=9.2");

  // Hold final frame
  tl.to({}, { duration: 4 / SPEED }, "scene3+=10.0");

  /* ========== INTERACTIONS ========== */
  const btnPlay = $("#btnPlay");
  const btnReplay = $("#btnReplay");

  btnPlay.addEventListener("click", () => {
    btnPlay.style.display = "none";
    tl.restart();
  });

  btnReplay.addEventListener("click", () => {
    btnReplay.style.display = "none";
    resetState();
    tl.restart();
  });

  // Keyboard
  document.addEventListener("keydown", (e) => {
    if (e.code === "Space") { e.preventDefault(); tl.paused() ? tl.play() : tl.pause(); }
    if (e.code === "KeyR") { resetState(); tl.restart(); }
  });

  // Tooltip on nodes
  const tooltip = $("#tooltip");
  $$(".tree-node").forEach((node) => {
    node.addEventListener("mouseenter", (e) => {
      const { label, share, addr } = node.dataset;
      tooltip.innerHTML = `<strong>${label}</strong><br>Share: ${share}<br>Creator: ${addr}`;
      tooltip.style.opacity = 1;
    });
    node.addEventListener("mousemove", (e) => {
      tooltip.style.left = e.clientX + 12 + "px";
      tooltip.style.top = e.clientY - 40 + "px";
    });
    node.addEventListener("mouseleave", () => { tooltip.style.opacity = 0; });
  });

  // Edge hover glow
  $$(".edge").forEach((edge) => {
    edge.addEventListener("mouseenter", () => { gsap.to(edge, { strokeWidth: 4, opacity: 1, duration: 0.2 }); });
    edge.addEventListener("mouseleave", () => { gsap.to(edge, { strokeWidth: 2.5, opacity: 0.7, duration: 0.3 }); });
  });

  /* ========== HELPERS ========== */
  function updateProgress() {
    const p = tl.progress() * 100;
    $("#progressFill").style.width = p + "%";
  }

  function onEnd() {
    btnReplay.style.display = "block";
  }

  function resetState() {
    $("#balA").textContent = "0.0000";
    $("#balB").textContent = "0.0000";
    $("#balC").textContent = "0.0000";
    $("#explorerUrl").textContent = "";
    $("#txHashValue").textContent = "";
    btnReplay.style.display = "none";
  }
})();
