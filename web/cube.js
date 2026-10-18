// Rdzeń: model kostki, ruchy, rozpoznawanie kolorów, walidacja i solver metodą warstwową z opisami po polsku.
// Działa w przeglądarce (globalny CubeCore) i w Node (module.exports).
(function (root) {
  "use strict";

  // Ściany w kolejności U R F D L B. Ściana = jej środek (środki się nie ruszają).
  const U = 0, R = 1, F = 2, D = 3, L = 4, B = 5;
  const FACES = "URFDLB";

  // ---------- Geometria naklejek ----------
  // Indeksy: U 0-8, R 9-17, F 18-26, D 27-35, L 36-44, B 45-53, każda ściana wierszami.
  // U widziana z góry (B u góry obrazka), D z dołu (F u góry), boki z U na górze.
  const NORMAL = [[0, 1, 0], [1, 0, 0], [0, 0, 1], [0, -1, 0], [-1, 0, 0], [0, 0, -1]];

  function stickerPos(f, r, c) {
    switch (f) {
      case U: return [c - 1, 1, r - 1];
      case D: return [c - 1, -1, 1 - r];
      case F: return [c - 1, 1 - r, 1];
      case B: return [1 - c, 1 - r, -1];
      case R: return [1, 1 - r, 1 - c];
      case L: return [-1, 1 - r, c - 1];
    }
  }

  const STICKERS = [];
  for (let f = 0; f < 6; f++)
    for (let r = 0; r < 3; r++)
      for (let c = 0; c < 3; c++)
        STICKERS.push({ index: f * 9 + r * 3 + c, face: f, pos: stickerPos(f, r, c), normal: NORMAL[f] });

  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  // Obrót o 90° zgodnie z ruchem wskazówek zegara, patrząc na ścianę o normalnej k z zewnątrz.
  function rotCW(p, k) {
    const kp = cross(k, p), d = dot(k, p);
    return [-kp[0] + k[0] * d, -kp[1] + k[1] * d, -kp[2] + k[2] * d];
  }

  function faceletPerm(face) {
    const k = NORMAL[face];
    const key = (p, n) => p.join() + "|" + n.join();
    const index = {};
    STICKERS.forEach((s) => { index[key(s.pos, s.normal)] = s.index; });
    const perm = [...Array(54).keys()];
    STICKERS.forEach((s) => {
      if (dot(s.pos, k) === 1) perm[index[key(rotCW(s.pos, k), rotCW(s.normal, k))]] = s.index;
    });
    return perm;
  }

  // ---------- Model kostek (cubie) ----------
  const fn = (s) => FACES.indexOf(s[0]) * 9 + Number(s[1]) - 1;
  const CORNER_FACELETS = [["U9", "R1", "F3"], ["U7", "F1", "L3"], ["U1", "L1", "B3"], ["U3", "B1", "R3"],
    ["D3", "F9", "R7"], ["D1", "L9", "F7"], ["D7", "B9", "L7"], ["D9", "R9", "B7"]].map((t) => t.map(fn));
  const EDGE_FACELETS = [["U6", "R2"], ["U8", "F2"], ["U4", "L2"], ["U2", "B2"], ["D6", "R8"], ["D2", "F8"],
    ["D4", "L8"], ["D8", "B8"], ["F6", "R4"], ["F4", "L6"], ["B6", "L4"], ["B4", "R6"]].map((t) => t.map(fn));
  const CORNER_FACES = CORNER_FACELETS.map((t) => t.map((i) => Math.floor(i / 9)));
  const EDGE_FACES = EDGE_FACELETS.map((t) => t.map((i) => Math.floor(i / 9)));

  const sameSet = (a, b) => a.length === b.length && a.every((x) => b.includes(x));
  const cornerAt = (faces) => CORNER_FACES.findIndex((t) => sameSet(t, faces));
  const edgeAt = (faces) => EDGE_FACES.findIndex((t) => sameSet(t, faces));

  class Cube {
    constructor(cp, co, ep, eo) {
      this.cp = cp || [0, 1, 2, 3, 4, 5, 6, 7];
      this.co = co || [0, 0, 0, 0, 0, 0, 0, 0];
      this.ep = ep || [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
      this.eo = eo || [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    }
    // Złożenie: najpierw this, potem b.
    mul(b) {
      const r = new Cube();
      for (let i = 0; i < 8; i++) { r.cp[i] = this.cp[b.cp[i]]; r.co[i] = (this.co[b.cp[i]] + b.co[i]) % 3; }
      for (let i = 0; i < 12; i++) { r.ep[i] = this.ep[b.ep[i]]; r.eo[i] = (this.eo[b.ep[i]] + b.eo[i]) % 2; }
      return r;
    }
    apply(moves) {
      let c = this;
      for (const m of moves) c = c.mul(MOVE_CUBES[m.face][m.turns]);
      return c;
    }
    key() { return this.cp.join() + "/" + this.co.join() + "/" + this.ep.join() + "/" + this.eo.join(); }
    isSolved() { return this.key() === SOLVED_KEY; }
    cornerSolved(i) { return this.cp[i] === i && this.co[i] === 0; }
    edgeSolved(i) { return this.ep[i] === i && this.eo[i] === 0; }
    cornerPos(piece) { return this.cp.indexOf(piece); }
    edgePos(piece) { return this.ep.indexOf(piece); }
    // Ściana (kolor środka) każdej z 54 naklejek.
    facelets() {
      const f = [];
      for (let i = 0; i < 54; i++) f.push(Math.floor(i / 9));
      for (let i = 0; i < 8; i++)
        for (let k = 0; k < 3; k++) f[CORNER_FACELETS[i][(k + this.co[i]) % 3]] = CORNER_FACES[this.cp[i]][k];
      for (let i = 0; i < 12; i++)
        for (let k = 0; k < 2; k++) f[EDGE_FACELETS[i][(k + this.eo[i]) % 2]] = EDGE_FACES[this.ep[i]][k];
      return f;
    }
    static fromFacelets(f) {
      const c = new Cube();
      for (let i = 0; i < 8; i++) {
        const fl = CORNER_FACELETS[i];
        let ori = -1;
        for (let o = 0; o < 3; o++) if (f[fl[o]] === U || f[fl[o]] === D) { ori = o; break; }
        if (ori < 0) return null;
        const c1 = f[fl[(ori + 1) % 3]], c2 = f[fl[(ori + 2) % 3]];
        const j = CORNER_FACES.findIndex((t) => t[1] === c1 && t[2] === c2);
        if (j < 0) return null;
        c.cp[i] = j; c.co[i] = ori;
      }
      for (let i = 0; i < 12; i++) {
        const a = f[EDGE_FACELETS[i][0]], b = f[EDGE_FACELETS[i][1]];
        let j = EDGE_FACES.findIndex((t) => t[0] === a && t[1] === b);
        if (j >= 0) { c.ep[i] = j; c.eo[i] = 0; continue; }
        j = EDGE_FACES.findIndex((t) => t[0] === b && t[1] === a);
        if (j < 0) return null;
        c.ep[i] = j; c.eo[i] = 1;
      }
      return c;
    }
  }
  const SOLVED_KEY = new Cube().key();

  // MOVE_CUBES[ściana][ćwierćobroty 0..3]
  const MOVE_CUBES = [];
  {
    const solved = new Cube().facelets();
    for (let f = 0; f < 6; f++) {
      const perm = faceletPerm(f);
      const q = Cube.fromFacelets(perm.map((i) => solved[i]));
      const powers = [new Cube()];
      for (let t = 1; t < 4; t++) powers.push(powers[t - 1].mul(q));
      MOVE_CUBES.push(powers);
    }
  }

  // ---------- Ruchy i zapis ----------
  const mv = (face, turns) => ({ face, turns: ((turns % 4) + 4) % 4 });
  const moveStr = (m) => FACES[m.face] + ["", "", "2", "'"][m.turns];
  const notation = (moves) => moves.map(moveStr).join(" ");
  function parse(text) {
    return text.trim().split(/\s+/).filter(Boolean).map((t) => mv(FACES.indexOf(t[0]), t[1] === "2" ? 2 : t[1] === "'" ? 3 : 1));
  }

  // Ustawienia kostki: żółty (U) zawsze u góry, do siebie jedna ze ścian bocznych.
  const HOLDS = [F, R, B, L];
  const rightOf = (f) => HOLDS[(HOLDS.indexOf(f) + 1) % 4];
  const backOf = (f) => HOLDS[(HOLDS.indexOf(f) + 2) % 4];
  const leftOf = (f) => HOLDS[(HOLDS.indexOf(f) + 3) % 4];
  function absFace(rel, front) {
    switch (rel) {
      case F: return front;
      case R: return rightOf(front);
      case B: return backOf(front);
      case L: return leftOf(front);
      default: return rel;
    }
  }
  const toAbs = (alg, front) => (typeof alg === "string" ? parse(alg) : alg).map((m) => mv(absFace(m.face, front), m.turns));
  const toRel = (moves, front) => moves.map((m) => mv([0, 1, 2, 3, 4, 5].find((r) => absFace(r, front) === m.face), m.turns));

  // ---------- Kolory ----------
  const COLORS = [
    { id: "white", name: "biały", fem: "biała", ins: "białym", gen: "białego", genF: "białej", genPl: "białych", pre: "biało", rgb: [0.96, 0.96, 0.96], ref: [0.85, 0.85, 0.85] },
    { id: "yellow", name: "żółty", fem: "żółta", ins: "żółtym", gen: "żółtego", genF: "żółtej", genPl: "żółtych", pre: "żółto", rgb: [1.0, 0.85, 0.0], ref: [0.85, 0.80, 0.10] },
    { id: "red", name: "czerwony", fem: "czerwona", ins: "czerwonym", gen: "czerwonego", genF: "czerwonej", genPl: "czerwonych", pre: "czerwono", rgb: [0.80, 0.07, 0.12], ref: [0.70, 0.08, 0.10] },
    { id: "orange", name: "pomarańczowy", fem: "pomarańczowa", ins: "pomarańczowym", gen: "pomarańczowego", genF: "pomarańczowej", genPl: "pomarańczowych", pre: "pomarańczowo", rgb: [1.0, 0.46, 0.0], ref: [0.95, 0.40, 0.08] },
    { id: "blue", name: "niebieski", fem: "niebieska", ins: "niebieskim", gen: "niebieskiego", genF: "niebieskiej", genPl: "niebieskich", pre: "niebiesko", rgb: [0.0, 0.32, 0.82], ref: [0.05, 0.25, 0.65] },
    { id: "green", name: "zielony", fem: "zielona", ins: "zielonym", gen: "zielonego", genF: "zielonej", genPl: "zielonych", pre: "zielono", rgb: [0.0, 0.62, 0.30], ref: [0.05, 0.60, 0.25] },
  ];
  const WHITE = 0, YELLOW = 1, RED = 2, ORANGE = 3, BLUE = 4, GREEN = 5;
  // Żółty u góry, zielony do siebie.
  const STANDARD_SCHEME = [YELLOW, ORANGE, GREEN, WHITE, RED, BLUE];

  function lab(rgb) {
    const lin = (c) => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
    const [r, g, b] = rgb.map(lin);
    const x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
    const y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    const z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
    const f = (t) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
    return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
  }
  // Jasność waży mniej niż barwa, bo oświetlenie zmienia głównie jasność.
  function dist(p, q) {
    const dl = (p[0] - q[0]) * 0.5, da = p[1] - q[1], db = p[2] - q[2];
    return Math.sqrt(dl * dl + da * da + db * db);
  }
  const REF_LABS = COLORS.map((c) => lab(c.ref));
  function guessColor(rgb) {
    const p = lab(rgb);
    let best = 0;
    for (let i = 1; i < 6; i++) if (dist(p, REF_LABS[i]) < dist(p, REF_LABS[best])) best = i;
    return best;
  }

  // Każdemu środkowi inny kolor: najlepsza z 720 permutacji.
  function assignCenters(centerRgbs) {
    const labs = centerRgbs.map(lab);
    let best = null, bestCost = Infinity;
    (function permute(cur, used, cost) {
      if (cost >= bestCost) return;
      if (cur.length === 6) { best = cur.slice(); bestCost = cost; return; }
      const i = cur.length;
      for (let c = 0; c < 6; c++) if (!used[c]) {
        used[c] = true; cur.push(c);
        permute(cur, used, cost + dist(labs[i], REF_LABS[c]));
        cur.pop(); used[c] = false;
      }
    })([], [], 0);
    return best;
  }

  // Klasyfikuje 54 próbki (U R F D L B): punktem odniesienia są środki z tego samego światła,
  // każdy kolor najwyżej 9 razy (przydział zachłanny od najpewniejszych par).
  // Zwraca kolory (indeksy COLORS) wszystkich naklejek.
  function classify(samples) {
    const labs = samples.map(lab);
    const centers = [0, 1, 2, 3, 4, 5].map((f) => labs[f * 9 + 4]);
    const pairs = [];
    for (let s = 0; s < 54; s++) for (let f = 0; f < 6; f++) pairs.push([dist(labs[s], centers[f]), s, f]);
    pairs.sort((a, b) => a[0] - b[0]);
    const face = Array(54).fill(-1), count = Array(6).fill(0);
    for (let f = 0; f < 6; f++) { face[f * 9 + 4] = f; count[f] = 1; }
    for (const [, s, f] of pairs) if (face[s] < 0 && count[f] < 9) { face[s] = f; count[f]++; }
    const scheme = assignCenters([0, 1, 2, 3, 4, 5].map((f) => samples[f * 9 + 4]));
    return face.map((f) => scheme[f]);
  }

  // ---------- Walidacja ----------
  function parity(p) {
    let s = 0;
    for (let i = 0; i < p.length; i++) for (let j = i + 1; j < p.length; j++) if (p[i] > p[j]) s++;
    return s % 2;
  }
  // colors: 54 indeksy kolorów. Zwraca {cube, scheme} albo {error}.
  function validate(colors) {
    const faceOf = {};
    for (let f = 0; f < 6; f++) faceOf[colors[f * 9 + 4]] = f;
    if (Object.keys(faceOf).length !== 6) return { error: "Dwa środki mają ten sam kolor. Każda ściana musi mieć inny środek." };
    for (let c = 0; c < 6; c++) {
      const n = colors.filter((x) => x === c).length;
      if (n !== 9) return { error: `Kolor ${COLORS[c].name} występuje ${n} razy, a powinien 9.` };
    }
    const cube = Cube.fromFacelets(colors.map((c) => faceOf[c]));
    if (!cube) return { error: "Któryś narożnik lub krawędź ma kombinację kolorów, której nie ma na kostce (np. dwa przeciwne kolory obok siebie). Sprawdź naklejki." };
    if (new Set(cube.cp).size !== 8 || new Set(cube.ep).size !== 12) return { error: "Ten sam element (narożnik lub krawędź) pojawia się dwa razy. Sprawdź naklejki." };
    if (cube.co.reduce((a, b) => a + b, 0) % 3) return { error: "Jeden narożnik jest obrócony w sposób niemożliwy do ułożenia. Najpewniej któraś naklejka jest źle rozpoznana." };
    if (cube.eo.reduce((a, b) => a + b, 0) % 2) return { error: "Jedna krawędź jest odwrócona w sposób niemożliwy do ułożenia. Najpewniej któraś naklejka jest źle rozpoznana." };
    if (parity(cube.cp) !== parity(cube.ep)) return { error: "Dwa elementy są zamienione miejscami w sposób niemożliwy do ułożenia. Sprawdź naklejki." };
    return { cube, scheme: [0, 1, 2, 3, 4, 5].map((f) => colors[f * 9 + 4]) };
  }

  // ---------- Solver ----------
  const STAGES = [
    null,
    { title: "Krzyż na dole", goal: (b, t) => `Ułóż ${b.name} krzyż na dolnej ścianie. Każda krawędź krzyża musi drugim kolorem pasować do środka ściany bocznej. Sam krzyż na dole to za mało.` },
    { title: "Narożniki pierwszej warstwy", goal: (b, t) => `Wstaw cztery narożniki z ${b.ins} kolorem w rogi dolnej warstwy. Po tym etapie cała pierwsza warstwa jest gotowa.` },
    { title: "Środkowa warstwa", goal: (b, t) => `Wstaw cztery krawędzie bez ${t.gen} koloru w środkową warstwę. Po tym etapie dwie warstwy są ułożone.` },
    { title: "Krzyż na górze", goal: (b, t) => `Ułóż ${t.name} krzyż na górnej ścianie. Na razie liczy się tylko góra, nie boki.` },
    { title: "Krawędzie górnej warstwy", goal: (b, t) => `Przestaw krawędzie górnego krzyża, żeby ich boczne kolory pasowały do środków.` },
    { title: "Narożniki na swoje miejsca", goal: (b, t) => `Przestaw górne narożniki na właściwe miejsca. Na razie mogą być obrócone.` },
    { title: "Obrót narożników", goal: (b, t) => `Obróć górne narożniki ${t.ins} kolorem do góry. To ostatni etap.` },
  ];

  const ALL18 = [];
  for (let f = 0; f < 6; f++) for (let t = 1; t <= 3; t++) ALL18.push([mv(f, t)]);

  // BFS po stanach wybranych elementów (pozycja + orientacja). Zwraca indeksy makr prowadzących do celu.
  function searchPieces(start, corners, edges, macros, maxDepth) {
    const tables = macros.map((ms) => {
      const m = new Cube().apply(ms);
      const cn = [], en = [];
      for (let i = 0; i < 8; i++) cn[m.cp[i]] = [i, m.co[i]];
      for (let i = 0; i < 12; i++) en[m.ep[i]] = [i, m.eo[i]];
      return { cn, en };
    });
    const nc = corners.length, n = corners.length + edges.length;
    const encode = (s) => s.reduce((a, x) => a * 36 + x, 0);
    const decode = (k) => { const s = Array(n); for (let i = n - 1; i >= 0; i--) { s[i] = k % 36; k = Math.floor(k / 36); } return s; };
    const st = [];
    for (const j of corners) { const p = start.cornerPos(j); st.push(p * 3 + start.co[p]); }
    for (const j of edges) { const p = start.edgePos(j); st.push(p * 3 + start.eo[p]); }
    const goal = encode(corners.map((j) => j * 3).concat(edges.map((j) => j * 3)));
    const startKey = encode(st);
    if (startKey === goal) return [];
    const parent = new Map([[startKey, null]]);
    let frontier = [startKey];
    for (let depth = 0; depth < maxDepth; depth++) {
      const next = [];
      for (const key of frontier) {
        const s = decode(key);
        for (let mi = 0; mi < tables.length; mi++) {
          const t = tables[mi], ns = Array(n);
          for (let i = 0; i < n; i++) {
            const pos = Math.floor(s[i] / 3), ori = s[i] % 3;
            if (i < nc) { const [np, d] = t.cn[pos]; ns[i] = np * 3 + (ori + d) % 3; }
            else { const [np, d] = t.en[pos]; ns[i] = np * 3 + (ori + d) % 2; }
          }
          const nk = encode(ns);
          if (parent.has(nk)) continue;
          parent.set(nk, [key, mi]);
          if (nk === goal) {
            const path = [];
            let k = nk;
            while (parent.get(k)) { const [pk, m] = parent.get(k); path.push(m); k = pk; }
            return path.reverse();
          }
          next.push(nk);
        }
      }
      frontier = next;
    }
    return null;
  }

  const RIGHT_INSERT = "U R U' R' U' F' U F";
  const LEFT_INSERT = "U' L' U L U F U' F'";

  // scheme[ściana] = indeks koloru środka.
  function solve(start, scheme) {
    const col = (f) => COLORS[scheme[f]];
    const bottom = col(D), top = col(U);
    const edgeName = (faces) => `${col(faces[0]).pre}-${col(faces[1]).fem}`;
    const cornerName = (faces) => `${col(faces[0]).pre}-${col(faces[1]).pre}-${col(faces[2]).name}`;
    const times = (n) => (n === 1 ? "1 raz" : `${n} razy`);
    const uTurn = (k) => (k % 4 === 0 ? [] : [mv(U, k)]);

    let cube = start;
    const steps = [];
    function emit(stage, title, explanation, front, moves, note) {
      steps.push({ id: steps.length, stage, title, explanation, front, moves,
        notation: note || notation(toRel(moves, front)) });
      cube = cube.apply(moves);
    }

    function edgeLocation(piece) {
      const pos = cube.edgePos(piece), faces = EDGE_FACES[pos];
      if (faces.includes(U)) return `w górnej warstwie, nad ${col(faces.find((f) => f !== U)).ins} środkiem`;
      if (faces.includes(D)) {
        if (pos === piece) return "na swoim miejscu na dole, ale odwrócona";
        return `w dolnej warstwie, pod ${col(faces.find((f) => f !== D)).ins} środkiem`;
      }
      return `w środkowej warstwie, między ${col(faces[0]).ins} a ${col(faces[1]).ins} środkiem`;
    }
    function cornerLocation(piece) {
      const pos = cube.cornerPos(piece);
      const sides = CORNER_FACES[pos].filter((f) => f !== U && f !== D);
      const pair = `${col(sides[0]).ins} i ${col(sides[1]).ins} środkiem`;
      if (pos < 4) return `w górnej warstwie, w rogu nad ${pair}`;
      if (pos === piece) return "na swoim miejscu, ale obrócony";
      return `w dolnej warstwie, w rogu pod ${pair}`;
    }

    const crossEdges = HOLDS.map((f) => edgeAt([D, f]));
    const bottomSlots = HOLDS.map((f) => cornerAt([D, f, rightOf(f)]));
    const middleSlots = HOLDS.map((f) => edgeAt([f, rightOf(f)]));
    const topEdges = HOLDS.map((f) => edgeAt([U, f]));
    const topCorners = HOLDS.map((f) => cornerAt([U, f, rightOf(f)]));

    // Etap 1: krzyż – krawędź po krawędzi, najkrótszą drogą bez psucia ułożonych.
    {
      const done = [];
      while (done.length < 4) {
        let best = null;
        for (const e of crossEdges) {
          if (done.includes(e)) continue;
          const p = searchPieces(cube, [], done.concat([e]), ALL18, 10);
          if (p && (!best || p.length < best.path.length)) best = { e, path: p };
        }
        const { e, path } = best;
        const side = EDGE_FACES[e][1];
        if (path.length) {
          let text = `Ta krawędź jest teraz ${edgeLocation(e)}. Jej miejsce jest na dole z przodu: ${bottom.fem} naklejka w dół, a druga (${col(side).fem}) z przodu, przy środku w tym samym kolorze.`;
          if (done.length) text += " Ruchy dobrano tak, żeby nie zepsuć ułożonych już krawędzi krzyża.";
          emit(1, `Krawędź ${edgeName(EDGE_FACES[e])}`, text, side, path.map((i) => ALL18[i][0]));
        }
        done.push(e);
      }
    }

    // Etap 2: narożniki pierwszej warstwy – (R U R' U') powtarzane.
    {
      const done = [];
      while (done.length < 4) {
        let best = null;
        for (const t of bottomSlots) {
          if (done.includes(t)) continue;
          const plan = [];
          let c = cube;
          const pos = c.cornerPos(t);
          if (pos >= 4 && pos !== t) {
            const f = HOLDS[bottomSlots.indexOf(pos)];
            const m = toAbs("R U R' U'", f);
            plan.push({ kind: "pop", front: f, moves: m });
            c = c.apply(m);
          }
          if (!c.cornerSolved(t)) {
            const f = HOLDS[bottomSlots.indexOf(t)];
            let moves = [], k = 0, n = 0;
            if (c.cornerPos(t) !== t) {
              const above = cornerAt([U, f, rightOf(f)]);
              while (c.cornerPos(t) !== above) { c = c.apply([mv(U, 1)]); k++; }
              moves = moves.concat(uTurn(k));
            }
            const sexy = toAbs("R U R' U'", f);
            while (!c.cornerSolved(t) && n < 6) { c = c.apply(sexy); n++; moves = moves.concat(sexy); }
            plan.push({ kind: "insert", front: f, moves, n, k });
          }
          const ok = c.cornerSolved(t) && done.every((x) => c.cornerSolved(x)) && crossEdges.every((x) => c.edgeSolved(x));
          if (!ok) continue;
          const len = plan.reduce((a, p) => a + p.moves.length, 0);
          if (!best || len < best.len) best = { t, len, plan };
        }
        const { t, plan } = best;
        const name = cornerName(CORNER_FACES[t]);
        for (const part of plan) {
          if (part.kind === "pop") {
            emit(2, `Wyjmij narożnik ${name}`,
              `Narożnik jest ${cornerLocation(t)}, ale to nie jego miejsce. Trzymaj kostkę tak, żeby był na dole z przodu po prawej. Jedno R U R' U' wyrzuci go do górnej warstwy, a krzyż zostanie nietknięty.`,
              part.front, part.moves, "R U R' U'");
          } else {
            const prefix = notation(toRel(uTurn(part.k), part.front));
            let text;
            if (part.k > 0) text = `Narożnik jest ${cornerLocation(t)}. Najpierw obróć górną warstwę (${prefix}), żeby stanął dokładnie nad swoim miejscem: u góry z przodu po prawej, nad rogiem między ${col(part.front).ins} i ${col(rightOf(part.front)).ins} środkiem. `;
            else if (cube.cornerPos(t) === t) text = "Narożnik jest na swoim miejscu, ale obrócony. ";
            else text = "Narożnik jest już nad swoim miejscem, u góry z przodu po prawej. ";
            text += `Teraz powtarzaj R U R' U' (tu: ${times(part.n)}), aż narożnik wskoczy na dół ${bottom.ins} kolorem w dół. Dlaczego to działa: każde powtórzenie obraca ten narożnik, a po 6 powtórzeniach kostka wraca do stanu wyjścia. Dlatego reszta dolnej warstwy się nie psuje.`;
            const reps = part.n === 1 ? "R U R' U'" : `(R U R' U') ×${part.n}`;
            emit(2, `Wstaw narożnik ${name}`, text, part.front, part.moves, prefix ? `${prefix}  ${reps}` : reps);
          }
        }
        done.push(t);
      }
    }

    // Etap 3: środkowa warstwa.
    {
      const done = [];
      while (done.length < 4) {
        let best = null;
        for (const t of middleSlots) {
          if (done.includes(t)) continue;
          const plan = [];
          let c = cube;
          const pos = c.edgePos(t);
          if (pos >= 8 && !c.edgeSolved(t)) {
            const f = HOLDS[middleSlots.indexOf(pos)];
            const m = toAbs(RIGHT_INSERT, f);
            plan.push({ kind: "pop", front: f, moves: m });
            c = c.apply(m);
          }
          if (!c.edgeSolved(t)) {
            let k = 0, side = F, topFace = U;
            while (k < 4) {
              const p = c.edgePos(t), fl = c.facelets();
              side = EDGE_FACES[p][1];
              topFace = fl[EDGE_FACELETS[p][0]];
              if (fl[EDGE_FACELETS[p][1]] === side) break;
              c = c.apply([mv(U, 1)]); k++;
            }
            const right = topFace === rightOf(side);
            const m = toAbs(right ? RIGHT_INSERT : LEFT_INSERT, side);
            c = c.apply(m);
            plan.push({ kind: "insert", front: side, moves: uTurn(k).concat(m), k, right });
          }
          const ok = c.edgeSolved(t) && done.every((x) => c.edgeSolved(x)) &&
            bottomSlots.every((x) => c.cornerSolved(x)) && crossEdges.every((x) => c.edgeSolved(x));
          if (!ok) continue;
          const len = plan.reduce((a, p) => a + p.moves.length, 0);
          if (!best || len < best.len) best = { t, len, plan };
        }
        const { t, plan } = best;
        const name = edgeName(EDGE_FACES[t]);
        for (const part of plan) {
          if (part.kind === "pop") {
            emit(3, `Wyjmij krawędź ${name}`,
              `Krawędź jest ${edgeLocation(t)}, w złym miejscu albo odwrócona. Trzymaj kostkę tak, żeby była w środkowej warstwie z przodu po prawej, i wykonaj algorytm wstawiania w prawo. Dowolna krawędź z góry zajmie jej miejsce, a ona wyskoczy do górnej warstwy.`,
              part.front, part.moves, RIGHT_INSERT);
          } else {
            const prefix = notation(toRel(uTurn(part.k), part.front));
            const topFace = EDGE_FACES[t].find((f) => f !== part.front);
            let text = part.k > 0
              ? `Obróć górną warstwę (${prefix}) tak, żeby przednia naklejka krawędzi stała nad ${col(part.front).ins} środkiem. Razem ze środkiem tworzy pionowy pasek (odwrócone T). `
              : `Przednia naklejka krawędzi już stoi nad ${col(part.front).ins} środkiem i tworzy z nim pionowy pasek (odwrócone T). `;
            const dir = part.right ? "prawej" : "lewej", dir2 = part.right ? "prawo" : "lewo";
            text += `Górna naklejka jest ${col(topFace).fem}, a ${col(topFace).ins} środek jest po ${dir}, więc krawędź wędruje w ${dir2}. Pierwsza połowa algorytmu odsuwa miejsce docelowe i wyjmuje z niego narożnik, druga wkłada krawędź razem z narożnikiem z powrotem. Pierwsza warstwa zostaje nietknięta.`;
            const alg = part.right ? RIGHT_INSERT : LEFT_INSERT;
            emit(3, `Wstaw krawędź ${name} w ${dir2}`, text, part.front, part.moves, prefix ? `${prefix}  ${alg}` : alg);
          }
        }
        done.push(t);
      }
    }

    // Etap 4: krzyż na górze – F R U R' U' F'.
    {
      const alg = "F R U R' U' F'";
      const why = `Algorytm ${alg} odwraca krawędzie górnej warstwy, nie psując dwóch dolnych warstw.`;
      for (let it = 0; it < 4; it++) {
        const up = topEdges.map((e) => cube.eo[e] === 0);
        const count = up.filter(Boolean).length;
        if (count === 4) break;
        if (count === 0) {
          emit(4, "Kropka → L", `Na górze nie ma żadnej ${top.genF} krawędzi, tylko środek (kropka). Wykonaj algorytm raz, a pojawi się kształt L albo linia. ${why}`, F, toAbs(alg, F));
          continue;
        }
        for (let i = 0; i < 4; i++) {
          const f = HOLDS[i], rf = up[i], rr = up[(i + 1) % 4], rb = up[(i + 2) % 4], rl = up[(i + 3) % 4];
          if (rb && rl && !rf && !rr) {
            emit(4, "Kształt L → krzyż", `Na górze jest ${top.name} kształt L. Trzymaj kostkę tak, żeby L było z tyłu i z lewej (jak wskazówki zegara na 9 i 12), i wykonaj algorytm. Powstanie krzyż. ${why}`, f, toAbs(alg, f));
            break;
          }
          if (rl && rr && !rf && !rb) {
            emit(4, "Linia → krzyż", `Na górze jest ${top.fem} linia. Trzymaj ją poziomo (od lewej do prawej) i wykonaj algorytm. Powstanie krzyż. ${why}`, f, toAbs(alg, f));
            break;
          }
        }
      }
    }

    // Etap 5: krawędzie górnej warstwy – R U R' U R U2 R'.
    {
      const sune = "R U R' U R U2 R'";
      const macros = [[mv(U, 1)], [mv(U, 3)], [mv(U, 2)]].concat(HOLDS.map((f) => toAbs(sune, f)));
      // Algorytm i obroty U nie ruszają dwóch dolnych warstw, więc wystarczy śledzić górne krawędzie.
      const path = searchPieces(cube, [], topEdges, macros, 6) || [];
      let pendingU = 0;
      for (const mi of path) {
        if (mi < 3) { pendingU += [1, 3, 2][mi]; continue; }
        const f = HOLDS[mi - 3];
        const prefix = uTurn(pendingU), prefixText = notation(toRel(prefix, f));
        let text = `Teraz boczne kolory ${top.genPl} krawędzi mają pasować do środków. `;
        if (prefix.length) text += `Najpierw obróć górę (${prefixText}). `;
        text += `Algorytm ${sune} zostawia krawędź z przodu na miejscu, a pozostałe trzy przesuwa w kółko. Nie psuje dwóch dolnych warstw ani krzyża na górze. Narożniki mogą się poprzestawiać, zajmiemy się nimi później.`;
        emit(5, "Przestaw krawędzie", text, f, prefix.concat(macros[mi]), prefixText ? `${prefixText}  ${sune}` : sune);
        pendingU = 0;
      }
      if (pendingU % 4) emit(5, "Dopasuj krawędzie do środków", "Obróć górę, żeby boczne kolory wszystkich krawędzi krzyża pasowały do środków.", F, uTurn(pendingU));
    }

    // Etap 6: narożniki na miejsca – U R U' L' U R' U' L.
    {
      const niklas = "U R U' L' U R' U' L";
      const macros = HOLDS.map((f) => toAbs(niklas, f));
      const keepE = crossEdges.concat(middleSlots, topEdges);
      const isGoal = (c) => topCorners.every((i) => c.cp[i] === i) && bottomSlots.every((i) => c.cornerSolved(i)) && keepE.every((i) => c.edgeSolved(i));
      const queue = [[cube, []]], seen = new Set([cube.key()]);
      let result = [];
      for (let h = 0; h < queue.length; h++) {
        const [c, path] = queue[h];
        if (isGoal(c)) { result = path; break; }
        if (path.length >= 3) continue;
        macros.forEach((m, mi) => {
          const n = c.apply(m);
          if (!seen.has(n.key())) { seen.add(n.key()); queue.push([n, path.concat([mi])]); }
        });
      }
      for (const mi of result) {
        const f = HOLDS[mi], fr = cornerAt([U, f, rightOf(f)]);
        let text = cube.cp[fr] === fr
          ? "Narożnik u góry z przodu po prawej jest już na swoim miejscu: jego kolory pasują do trzech sąsiednich środków (może być obrócony, to nic). Trzymaj go tam. "
          : "Żaden narożnik nie jest jeszcze na swoim miejscu. Wykonaj algorytm raz, a potem przynajmniej jeden będzie na miejscu. ";
        text += `Algorytm ${niklas} przestawia w kółko trzy narożniki, wszystkie poza przednim prawym, i nie rusza niczego innego.`;
        emit(6, "Przestaw narożniki", text, f, macros[mi], niklas);
      }
    }

    // Etap 7: obrót narożników – (R' D' R D) parami.
    {
      const allOriented = (c) => topCorners.every((i) => c.co[i] === 0);
      let front = F;
      if (!allOriented(cube)) {
        front = HOLDS.find((f) => cube.co[cornerAt([U, f, rightOf(f)])] !== 0);
        const fr = cornerAt([U, front, rightOf(front)]);
        const twist = toAbs("R' D' R D R' D' R D", front);
        const plan = [];
        let c = cube, pendingU = 0;
        for (let it = 0; it < 4; it++) {
          if (allOriented(c)) break;
          if (c.co[fr] !== 0) {
            let pairs = 0;
            while (c.co[fr] !== 0 && pairs < 3) { c = c.apply(twist); pairs++; }
            plan.push({ u: pendingU, pairs });
            pendingU = 0;
          }
          if (!allOriented(c)) { c = c.apply([mv(U, 1)]); pendingU++; }
        }
        plan.forEach((p, i) => {
          const prefix = uTurn(p.u);
          let moves = prefix.slice();
          for (let k = 0; k < p.pairs; k++) moves = moves.concat(twist);
          let text = prefix.length
            ? `Obróć tylko górną warstwę (${notation(prefix)}), żeby kolejny narożnik bez ${top.gen} koloru na górze trafił na przód-prawo. Całej kostki nie obracaj. `
            : `Narożnik u góry z przodu po prawej nie ma ${top.gen} koloru na górze. `;
          text += `Powtarzaj R' D' R D, aż ${top.name} kolor będzie na górze (tu: ${times(p.pairs * 2)}).`;
          text += i === 0
            ? " Uwaga: dolne warstwy się teraz rozsypią. To normalne, wrócą na miejsce, gdy obrócisz wszystkie narożniki. Przez cały ten etap trzymaj kostkę tak samo i obracaj tylko górną warstwę."
            : " Dolne warstwy nadal wyglądają na pomieszane. Tak ma być.";
          const reps = `(R' D' R D) ×${p.pairs * 2}`;
          emit(7, "Obróć narożnik", text, front, moves, prefix.length ? `${notation(prefix)}  ${reps}` : reps);
        });
      }
      let k = 0, c = cube;
      while (!c.isSolved() && k < 4) { c = c.apply([mv(U, 1)]); k++; }
      if (k % 4) emit(7, "Ostatni ruch", `Wszystkie narożniki są obrócone. Obróć jeszcze górną warstwę (${notation(uTurn(k))}), żeby pasowała do reszty. Kostka ułożona!`, front, uTurn(k));
    }

    // Etapy bez kroków oznacz jako gotowe.
    const all = [];
    for (let s = 1; s <= 7; s++) {
      const own = steps.filter((x) => x.stage === s);
      if (own.length) all.push(...own);
      else all.push({ stage: s, title: "Już gotowe", explanation: "Ten etap jest już ułożony. Możesz przejść dalej.", front: F, moves: [], notation: "" });
    }
    all.forEach((s, i) => { s.id = i; });
    return { start, steps: all, solved: cube.isSolved() };
  }

  function describeMove(m) {
    const t = {
      "R": "Prawa ściana do góry (od siebie)", "R'": "Prawa ściana w dół (do siebie)",
      "L": "Lewa ściana w dół (do siebie)", "L'": "Lewa ściana do góry (od siebie)",
      "U": "Górna warstwa w lewo", "U'": "Górna warstwa w prawo",
      "D": "Dolna warstwa w prawo", "D'": "Dolna warstwa w lewo",
      "F": "Przednia ściana zgodnie z ruchem wskazówek zegara", "F'": "Przednia ściana przeciwnie do ruchu wskazówek zegara",
      "B": "Tylna ściana: patrząc od przodu, przeciwnie do wskazówek zegara (góra jedzie w lewo)",
      "B'": "Tylna ściana: patrząc od przodu, zgodnie ze wskazówkami zegara (góra jedzie w prawo)",
    };
    const names = ["Górna warstwa", "Prawa ściana", "Przednia ściana", "Dolna warstwa", "Lewa ściana", "Tylna ściana"];
    return t[moveStr(m)] || `${names[m.face]} o pół obrotu (180°, kierunek dowolny)`;
  }

  function randomScramble(n) {
    const moves = [];
    let last = -1;
    while (moves.length < (n || 25)) {
      const f = Math.floor(Math.random() * 6);
      if (f === last) continue;
      last = f;
      moves.push(mv(f, 1 + Math.floor(Math.random() * 3)));
    }
    return moves;
  }

  const api = {
    U, R, F, D, L, B, FACES, HOLDS, COLORS, STANDARD_SCHEME, STAGES, STICKERS, NORMAL,
    Cube, mv, parse, notation, moveStr, toAbs, toRel, describeMove, randomScramble,
    guessColor, classify, assignCenters, validate, solve,
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.CubeCore = api;
})(typeof window !== "undefined" ? window : globalThis);
