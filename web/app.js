(function () {
  "use strict";
  const C = window.CubeCore;
  const { U, R, F, D, L, B, COLORS, STANDARD_SCHEME } = C;
  const $ = (id) => document.getElementById(id);
  const css = (c) => `rgb(${COLORS[c].rgb.map((x) => Math.round(x * 255)).join(",")})`;

  const state = {
    view: "home",
    colors: solvedColors(),
    brush: 0,
    solution: null,
    scheme: STANDARD_SCHEME.slice(),
    stepIndex: 0,
    moveIndex: 0,
  };

  function solvedColors() { return new C.Cube().facelets().map((f) => STANDARD_SCHEME[f]); }
  function scrambledColors() { return new C.Cube().apply(C.randomScramble(25)).facelets().map((f) => STANDARD_SCHEME[f]); }

  // ---------- Nawigacja ----------
  const history = [];
  function show(view, push = true) {
    if (push && state.view !== view) history.push(state.view);
    state.view = view;
    for (const v of ["home", "scan", "editor", "solution"]) $("v-" + v).hidden = v !== view;
    window.scrollTo(0, 0);
    if (view === "solution") scene.resize();
  }
  document.querySelectorAll("[data-back]").forEach((b) => b.addEventListener("click", () => {
    show(history.pop() || "home", false);
  }));

  // ---------- Start ----------
  [1, 5, 3, 4, 1, 2, 0, 5, 1].forEach((c) => {
    const i = document.createElement("i"); i.style.background = css(c); $("logo").appendChild(i);
  });
  ["R", "R'", "L", "L'", "U", "U'", "D", "D'", "F", "F'", "B", "B'", "U2"].forEach((s) => {
    const b = document.createElement("b"); b.textContent = s;
    const span = document.createElement("span"); span.textContent = C.describeMove(C.parse(s)[0]);
    $("notation-table").append(b, span);
  });
  $("go-scan").onclick = () => { scan.reset(); show("scan"); };
  $("go-manual").onclick = () => { state.colors = solvedColors(); renderEditor(); show("editor"); };
  $("go-demo").onclick = () => { state.colors = scrambledColors(); renderEditor(); show("editor"); };

  // ---------- Skanowanie ----------
  const ORDER = [
    { face: F, title: "Przód", hint: "Trzymaj kostkę żółtym środkiem do góry, a zielonym w stronę aparatu." },
    { face: R, title: "Prawa strona", hint: "Obróć całą kostkę o ćwierć obrotu w lewo (żółty dalej u góry). Do aparatu patrzy teraz ściana, która była po prawej." },
    { face: B, title: "Tył", hint: "Jeszcze raz ćwierć obrotu w lewo. Do aparatu patrzy ściana, która na początku była z tyłu." },
    { face: L, title: "Lewa strona", hint: "I jeszcze raz ćwierć obrotu w lewo: ściana, która była po lewej." },
    { face: U, title: "Góra", hint: "Wróć zieloną ścianą do siebie i przechyl kostkę górą do aparatu: żółty środek na wprost, zielona ściana na dole zdjęcia." },
    { face: D, title: "Dół", hint: "Teraz dół: biały środek do aparatu, zielona ściana na górze zdjęcia." },
  ];
  const scan = {
    step: 0, captured: {}, img: null, pixels: null, grid: { x: 0.5, y: 0.5, size: 0.7 }, samples: null,
    reset() { this.step = 0; this.captured = {}; this.clearPhoto(); this.render(); },
    clearPhoto() { this.img = null; this.pixels = null; this.samples = null; this.draw(); },
    render() {
      const o = ORDER[this.step];
      $("scan-title").textContent = `Skanowanie ${this.step + 1}/6`;
      $("scan-face").textContent = o.title;
      $("scan-hint").textContent = o.hint;
      $("scan-dot").style.background = css(STANDARD_SCHEME[o.face]);
      $("scan-prev").disabled = this.step === 0;
      const prog = $("scan-progress"); prog.innerHTML = "";
      ORDER.forEach((it, i) => {
        const s = document.createElement("span");
        if (i === this.step) s.className = "now";
        const cap = this.captured[it.face];
        if (cap) cap.forEach((rgb) => { const c = document.createElement("i"); c.style.background = css(C.guessColor(rgb)); s.appendChild(c); });
        prog.appendChild(s);
      });
      $("scan-ok").textContent = this.step === 5 ? "Zatwierdź i sprawdź kolory" : "Zatwierdź ścianę";
    },
    load(file) {
      if (!file) return;
      const url = URL.createObjectURL(file);
      const img = new Image();
      img.onload = () => {
        const canvas = $("scan-canvas");
        // Kadr 3:4; zdjęcie wypełnia go (środek).
        const W = 600, H = 800;
        canvas.width = W; canvas.height = H;
        const off = document.createElement("canvas"); off.width = W; off.height = H;
        const ctx = off.getContext("2d");
        const s = Math.max(W / img.naturalWidth, H / img.naturalHeight);
        const w = img.naturalWidth * s, h = img.naturalHeight * s;
        ctx.drawImage(img, (W - w) / 2, (H - h) / 2, w, h);
        this.img = off;
        this.pixels = ctx.getImageData(0, 0, W, H);
        this.grid = { x: 0.5, y: 0.5, size: Number($("grid-size").value) / 100 };
        URL.revokeObjectURL(url);
        this.update();
      };
      img.onerror = () => { URL.revokeObjectURL(url); alertBox("Nie udało się wczytać zdjęcia. Spróbuj jeszcze raz."); };
      img.src = url;
    },
    geometry() {
      const W = 600, H = 800, side = this.grid.size * W;
      return { side, x0: this.grid.x * W - side / 2, y0: this.grid.y * H - side / 2 };
    },
    sample() {
      const { side, x0, y0 } = this.geometry(), cell = side / 3, P = this.pixels, out = [];
      for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) {
        let sr = 0, sg = 0, sb = 0, n = 0;
        for (let y = Math.round(y0 + (r + 0.3) * cell); y < y0 + (r + 0.7) * cell; y += 2) {
          if (y < 0 || y >= P.height) continue;
          for (let x = Math.round(x0 + (c + 0.3) * cell); x < x0 + (c + 0.7) * cell; x += 2) {
            if (x < 0 || x >= P.width) continue;
            const i = (y * P.width + x) * 4;
            sr += P.data[i]; sg += P.data[i + 1]; sb += P.data[i + 2]; n++;
          }
        }
        n = Math.max(n, 1);
        out.push([sr / n / 255, sg / n / 255, sb / n / 255]);
      }
      return out;
    },
    update() { if (this.pixels) this.samples = this.sample(); this.draw(); },
    draw() {
      const canvas = $("scan-canvas"), ctx = canvas.getContext("2d");
      const has = !!this.img;
      $("scan-empty").hidden = has;
      $("scan-adjust").hidden = !has;
      $("scan-ok").disabled = !has;
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      if (!has) return;
      ctx.drawImage(this.img, 0, 0);
      const { side, x0, y0 } = this.geometry(), cell = side / 3;
      ctx.fillStyle = "rgba(0,0,0,0.35)";
      ctx.beginPath(); ctx.rect(0, 0, canvas.width, canvas.height); ctx.rect(x0, y0, side, side); ctx.fill("evenodd");
      ctx.lineWidth = 4; ctx.strokeStyle = "#fff";
      for (let r = 0; r < 3; r++) for (let c = 0; c < 3; c++) {
        ctx.strokeRect(x0 + c * cell + 4, y0 + r * cell + 4, cell - 8, cell - 8);
        if (this.samples) {
          const col = C.guessColor(this.samples[r * 3 + c]);
          ctx.beginPath();
          ctx.arc(x0 + (c + 0.78) * cell, y0 + (r + 0.78) * cell, cell * 0.1, 0, Math.PI * 2);
          ctx.fillStyle = css(col); ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = "#000"; ctx.stroke();
          ctx.lineWidth = 4; ctx.strokeStyle = "#fff";
        }
      }
    },
    confirm() {
      if (!this.samples) return;
      this.captured[ORDER[this.step].face] = this.samples;
      if (this.step === 5) {
        const all = [];
        for (let f = 0; f < 6; f++) all.push(...this.captured[f]);
        state.colors = C.classify(all);
        renderEditor();
        history.length = 0; history.push("home");
        state.view = "scan";
        show("editor", false);
        return;
      }
      this.step++;
      this.clearPhoto();
      this.render();
    },
  };
  $("file-camera").onchange = (e) => { scan.load(e.target.files[0]); e.target.value = ""; };
  $("file-gallery").onchange = (e) => { scan.load(e.target.files[0]); e.target.value = ""; };
  $("grid-size").oninput = (e) => { scan.grid.size = Number(e.target.value) / 100; scan.update(); };
  $("scan-ok").onclick = () => scan.confirm();
  $("scan-prev").onclick = () => {
    if (scan.step === 0) return;
    scan.step--; delete scan.captured[ORDER[scan.step].face]; scan.clearPhoto(); scan.render();
  };
  {
    // Przesuwanie siatki palcem.
    const box = $("scan-canvas");
    let drag = null;
    box.addEventListener("pointerdown", (e) => {
      if (!scan.img) return;
      box.setPointerCapture(e.pointerId);
      drag = { x: e.clientX, y: e.clientY, gx: scan.grid.x, gy: scan.grid.y };
    });
    box.addEventListener("pointermove", (e) => {
      if (!drag) return;
      const rect = box.getBoundingClientRect();
      scan.grid.x = Math.min(1, Math.max(0, drag.gx + (e.clientX - drag.x) / rect.width));
      scan.grid.y = Math.min(1, Math.max(0, drag.gy + (e.clientY - drag.y) / rect.height));
      scan.update();
    });
    const end = () => { drag = null; };
    box.addEventListener("pointerup", end);
    box.addEventListener("pointercancel", end);
  }
  function alertBox(text) { $("scan-hint").textContent = text; }

  // ---------- Edytor ----------
  const NET = [[U, 1, 0], [L, 0, 1], [F, 1, 1], [R, 2, 1], [B, 3, 1], [D, 1, 2]];
  const POS_NAME = ["Góra", "Prawa", "Przód", "Dół", "Lewa", "Tył"];
  function renderEditor() {
    const net = $("net"); net.innerHTML = "";
    for (const [face, col, row] of NET) {
      const box = document.createElement("div");
      box.className = "netface";
      box.style.gridColumn = String(col + 1); box.style.gridRow = String(row + 1);
      const lbl = document.createElement("span"); lbl.className = "lbl"; lbl.textContent = POS_NAME[face];
      box.appendChild(lbl);
      for (let i = 0; i < 9; i++) {
        const idx = face * 9 + i, b = document.createElement("button");
        b.className = "sticker"; b.style.background = css(state.colors[idx]);
        b.setAttribute("aria-label", `${POS_NAME[face]}, pole ${i + 1}: ${COLORS[state.colors[idx]].name}`);
        b.onclick = () => { state.colors[idx] = state.brush; $("editor-error").hidden = true; renderEditor(); };
        box.appendChild(b);
      }
      net.appendChild(box);
    }
    const pal = $("palette"); pal.innerHTML = "";
    COLORS.forEach((c, i) => {
      const wrap = document.createElement("div"); wrap.className = "stack"; wrap.style.gap = "4px";
      const b = document.createElement("button");
      b.className = "swatch" + (state.brush === i ? " sel" : ""); b.style.background = css(i);
      b.setAttribute("aria-label", `Pędzel: ${c.name}`);
      b.onclick = () => { state.brush = i; renderEditor(); };
      const n = state.colors.filter((x) => x === i).length;
      const cnt = document.createElement("div"); cnt.className = "count" + (n === 9 ? "" : " off"); cnt.textContent = `${n}/9`;
      wrap.append(b, cnt); pal.appendChild(wrap);
    });
  }
  $("reset-btn").onclick = () => { state.colors = solvedColors(); $("editor-error").hidden = true; renderEditor(); };
  $("shuffle-btn").onclick = () => { state.colors = scrambledColors(); $("editor-error").hidden = true; renderEditor(); };
  $("solve-btn").onclick = () => {
    const v = C.validate(state.colors);
    if (v.error) { $("editor-error").textContent = v.error; $("editor-error").hidden = false; return; }
    state.scheme = v.scheme;
    state.solution = C.solve(v.cube, v.scheme);
    scene.setScheme(v.scheme);
    show("solution");
    jump(0, 0, true);
  };

  // ---------- Scena 3D ----------
  const scene = (() => {
    const host = $("stage3d");
    if (!window.THREE) {
      const p = document.createElement("p"); p.className = "muted"; p.style.padding = "70px 16px 16px";
      p.textContent = "Nie udało się wczytać podglądu 3D. Instrukcje poniżej działają normalnie.";
      host.appendChild(p);
      return { setScheme() {}, show() {}, setFront() {}, animate(m, a, done) { done(); }, resize() {} };
    }
    const T = window.THREE;
    const renderer = new T.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    host.insertBefore(renderer.domElement, host.firstChild);
    const sc = new T.Scene();
    const camera = new T.PerspectiveCamera(36, 1, 0.1, 100);
    sc.add(new T.AmbientLight(0xffffff, 0.65));
    const light = new T.DirectionalLight(0xffffff, 0.55);
    sc.add(light);
    const root = new T.Group(); sc.add(root);
    let scheme = STANDARD_SCHEME.slice(), camAngle = 0, camTarget = 0;

    const bodyMat = new T.MeshLambertMaterial({ color: 0x14181c });
    const boxGeo = new T.BoxGeometry(0.95, 0.95, 0.95);
    const planeGeo = new T.PlaneGeometry(0.8, 0.8);
    const cubies = [];
    for (let x = -1; x <= 1; x++) for (let y = -1; y <= 1; y++) for (let z = -1; z <= 1; z++) {
      if (!x && !y && !z) continue;
      const m = new T.Mesh(boxGeo, bodyMat);
      m.userData = { home: [x, y, z], stickers: [] };
      cubies.push(m); root.add(m);
    }
    for (const s of C.STICKERS) {
      const cub = cubies.find((c) => c.userData.home.every((v, i) => v === s.pos[i]));
      const mat = new T.MeshLambertMaterial({ color: 0xffffff });
      const p = new T.Mesh(planeGeo, mat);
      const n = s.normal;
      p.position.set(n[0] * 0.478, n[1] * 0.478, n[2] * 0.478);
      p.lookAt(n[0] * 2, n[1] * 2, n[2] * 2);
      cub.add(p);
      cub.userData.stickers.push({ index: s.index, mat });
    }
    function show(cube) {
      const fl = cube.facelets();
      for (const c of cubies) {
        if (c.parent !== root) root.attach(c);
        c.position.set(...c.userData.home); c.rotation.set(0, 0, 0);
        for (const st of c.userData.stickers) st.mat.color.setRGB(...COLORS[scheme[fl[st.index]]].rgb);
      }
      render();
    }
    function placeCamera() {
      const base = new T.Vector3(3.4, 4.2, 7.6);
      const cs = Math.cos(camAngle), sn = Math.sin(camAngle);
      camera.position.set(base.x * cs + base.z * sn, base.y, -base.x * sn + base.z * cs);
      camera.lookAt(0, 0.45, 0);
      light.position.copy(camera.position).add(new T.Vector3(0, 3, 0));
    }
    function render() { placeCamera(); renderer.render(sc, camera); }
    function resize() {
      const w = host.clientWidth, h = host.clientHeight;
      if (!w || !h) return;
      renderer.setSize(w, h, false);
      camera.aspect = w / h; camera.updateProjectionMatrix();
      render();
    }
    window.addEventListener("resize", resize);
    const reduced = window.matchMedia && matchMedia("(prefers-reduced-motion: reduce)").matches;
    function tween(duration, step, done) {
      if (reduced) duration = Math.min(duration, 80);
      const t0 = performance.now();
      (function frame(now) {
        const t = Math.min(1, (now - t0) / duration);
        step(t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2);
        render();
        if (t < 1) requestAnimationFrame(frame); else done && done();
      })(t0);
    }
    function setFront(front, animated) {
      const angles = { [F]: 0, [R]: Math.PI / 2, [B]: Math.PI, [L]: -Math.PI / 2 };
      let delta = (angles[front] || 0) - camTarget;
      delta = Math.atan2(Math.sin(delta), Math.cos(delta));
      const from = camAngle;
      camTarget = camTarget + delta;
      const to = camTarget;
      if (!animated) { camAngle = to; render(); return; }
      tween(600, (k) => { camAngle = from + (to - from) * k; });
    }
    function animate(move, after, done) {
      const n = C.NORMAL[move.face];
      const pivot = new T.Group(); root.add(pivot);
      for (const c of cubies) {
        const h = c.userData.home;
        if (h[0] * n[0] + h[1] * n[1] + h[2] * n[2] === 1) pivot.attach(c);
      }
      const axis = new T.Vector3(n[0], n[1], n[2]);
      const angle = move.turns === 3 ? Math.PI / 2 : -Math.PI / 2 * move.turns;
      tween(move.turns === 2 ? 650 : 420, (k) => { pivot.setRotationFromAxisAngle(axis, angle * k); }, () => {
        show(after); root.remove(pivot); done();
      });
    }
    return { setScheme(s) { scheme = s.slice(); }, show, setFront, animate, resize };
  })();

  // ---------- Odtwarzacz rozwiązania ----------
  let animating = false, playing = false;
  function stateAt(si, mi) {
    const sol = state.solution;
    let c = sol.start;
    for (let i = 0; i < si; i++) c = c.apply(sol.steps[i].moves);
    return c.apply(sol.steps[si].moves.slice(0, mi));
  }
  function jump(si, mi, first) {
    playing = false;
    const sol = state.solution;
    const frontChanged = first || sol.steps[si].front !== sol.steps[state.stepIndex].front;
    state.stepIndex = si; state.moveIndex = mi;
    scene.show(stateAt(si, mi));
    scene.setFront(sol.steps[si].front, !first && frontChanged);
    renderStep();
  }
  function renderStep() {
    const sol = state.solution, step = sol.steps[state.stepIndex];
    const col = (f) => COLORS[state.scheme[f]];
    const stage = C.STAGES[step.stage];
    const firstOfStage = sol.steps.findIndex((s) => s.stage === step.stage) === state.stepIndex;
    const total = sol.steps.reduce((a, s) => a + s.moves.length, 0);
    $("hold").innerHTML = "";
    const hdr = document.createElement("span"); hdr.className = "eyebrow"; hdr.textContent = "Trzymaj kostkę";
    $("hold").appendChild(hdr);
    for (const [f, label] of [[U, "u góry"], [step.front, "do siebie"]]) {
      const row = document.createElement("div");
      const dot = document.createElement("span"); dot.className = "dot"; dot.style.background = css(state.scheme[f]);
      const t = document.createElement("span"); t.textContent = `${col(f).name} ${label}`;
      row.append(dot, t); $("hold").appendChild(row);
    }
    $("sol-stage").textContent = `Etap ${step.stage}/7 · ${stage.title}`;
    $("sol-goal").textContent = firstOfStage ? stage.goal(col(D), col(U)) : "";
    $("sol-goal").hidden = !firstOfStage;
    $("sol-title").textContent = step.title;
    $("sol-count").textContent = `Krok ${state.stepIndex + 1} z ${sol.steps.length} · łącznie ${total} ruchów`;
    const rel = C.toRel(step.moves, step.front);
    $("sol-moves").hidden = rel.length === 0;
    $("sol-notation").textContent = step.notation;
    const chips = $("sol-chips"); chips.innerHTML = "";
    rel.forEach((m, i) => {
      const s = document.createElement("span");
      s.className = "chip" + (i < state.moveIndex ? " done" : i === state.moveIndex ? " now" : "");
      s.textContent = C.moveStr(m); chips.appendChild(s);
      if (i === state.moveIndex) requestAnimationFrame(() => s.scrollIntoView({ block: "nearest", inline: "center" }));
    });
    const md = $("sol-movedesc");
    if (state.moveIndex < rel.length) { md.textContent = "↻ " + C.describeMove(rel[state.moveIndex]); md.className = "movedesc"; }
    else { md.textContent = "✓ Krok wykonany"; md.className = "movedesc ok"; }
    $("sol-explain").textContent = step.explanation;
    const atEnd = state.moveIndex >= step.moves.length, last = state.stepIndex === sol.steps.length - 1;
    $("sol-done").hidden = !(atEnd && last);
    $("c-back").disabled = animating || (state.stepIndex === 0 && state.moveIndex === 0);
    $("c-next").disabled = animating || atEnd;
    $("c-play").disabled = atEnd || (animating && !playing);
    $("c-play").textContent = playing ? "❚❚" : "▶︎▶︎";
    $("c-play").setAttribute("aria-label", playing ? "Pauza" : "Odtwórz krok");
    $("c-step").disabled = animating || last;
  }
  function animateNext(done) {
    const step = state.solution.steps[state.stepIndex];
    if (state.moveIndex >= step.moves.length) return;
    animating = true; renderStep();
    const after = stateAt(state.stepIndex, state.moveIndex + 1);
    scene.animate(step.moves[state.moveIndex], after, () => {
      state.moveIndex++; animating = false; renderStep(); done && done();
    });
  }
  function playNext() {
    if (!playing) return;
    if (state.moveIndex >= state.solution.steps[state.stepIndex].moves.length) { playing = false; renderStep(); return; }
    animateNext(() => setTimeout(playNext, 150));
  }
  $("c-next").onclick = () => animateNext();
  $("c-play").onclick = () => { if (playing) { playing = false; renderStep(); } else { playing = true; playNext(); } };
  $("c-back").onclick = () => {
    if (state.moveIndex > 0) jump(state.stepIndex, state.moveIndex - 1);
    else if (state.stepIndex > 0) jump(state.stepIndex - 1, state.solution.steps[state.stepIndex - 1].moves.length);
  };
  $("c-step").onclick = () => { jump(state.stepIndex + 1, 0); window.scrollTo(0, 0); };
  $("list-btn").onclick = () => {
    const list = $("steplist"); list.innerHTML = "";
    for (let s = 1; s <= 7; s++) {
      const sec = document.createElement("div");
      const h = document.createElement("h3"); h.textContent = `${s}. ${C.STAGES[s].title}`; sec.appendChild(h);
      state.solution.steps.filter((x) => x.stage === s).forEach((st) => {
        const b = document.createElement("button");
        if (st.id === state.stepIndex) b.className = "cur";
        const t = document.createElement("b"); t.textContent = st.title; b.appendChild(t);
        if (st.notation) { const n = document.createElement("small"); n.textContent = st.notation; b.appendChild(n); }
        b.onclick = () => { $("sheet").hidden = true; jump(st.id, 0); };
        sec.appendChild(b);
      });
      list.appendChild(sec);
    }
    $("sheet").hidden = false;
  };
  $("sheet-close").onclick = () => { $("sheet").hidden = true; };
  $("sheet").onclick = (e) => { if (e.target === $("sheet")) $("sheet").hidden = true; };

  renderEditor();
  scan.render();
})();
