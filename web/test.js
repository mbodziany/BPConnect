// Testy rdzenia: node web/test.js
const C = require("./cube.js");
const assert = require("assert");

const solved = new C.Cube();
for (let f = 0; f < 6; f++) assert(solved.apply(Array(4).fill(C.mv(f, 1))).isSolved(), "ruch^4 = id");
assert(solved.apply([].concat(...Array(6).fill(C.parse("R U R' U'")))).isSolved(), "(R U R' U')^6 = id");

const r = solved.apply(C.parse("R")).facelets();
assert.deepStrictEqual([r[2], r[5], r[8]], [C.F, C.F, C.F], "R podnosi przód na górę");
const u = solved.apply(C.parse("U")).facelets();
assert.deepStrictEqual(u.slice(18, 21), [C.R, C.R, C.R], "U przesuwa prawą na przód");
assert.strictEqual(C.notation(C.toAbs("R U F", C.R)), "B U R");

const scr = solved.apply(C.parse("R U F D L B R2 U' F2"));
assert.strictEqual(C.Cube.fromFacelets(scr.facelets()).key(), scr.key());

// Walidacja
const colorsOf = (cube) => cube.facelets().map((f) => C.STANDARD_SCHEME[f]);
assert(!C.validate(colorsOf(solved)).error);
const bad = colorsOf(solved); [bad[0], bad[9]] = [bad[9], bad[0]];
assert(C.validate(bad).error);

// Klasyfikacja przyciemnionych kolorów
const sc = solved.apply(C.parse("R U2 F' L D B2"));
const samples = sc.facelets().map((f) => C.COLORS[C.STANDARD_SCHEME[f]].rgb.map((x) => x * 0.7));
assert.deepStrictEqual(C.classify(samples), colorsOf(sc));

// Rozwiązywanie
const N = Number(process.argv[2] || 500);
let total = 0, t0 = Date.now();
for (let i = 0; i < N; i++) {
  const start = solved.apply(C.randomScramble(25));
  const sol = C.solve(start, C.STANDARD_SCHEME);
  const end = start.apply([].concat(...sol.steps.map((s) => s.moves)));
  assert(end.isSolved() && sol.solved, "nie ułożono");
  assert.strictEqual(sol.steps.filter((s) => s.stage === 1).length > 0, true);
  total += sol.steps.reduce((a, s) => a + s.moves.length, 0);
}
const solvedSol = C.solve(solved, C.STANDARD_SCHEME);
assert.strictEqual(solvedSol.steps.length, 7);
console.log(`OK: ${N} pomieszań ułożonych, średnio ${(total / N).toFixed(1)} ruchów, ${((Date.now() - t0) / N).toFixed(1)} ms/kostkę`);
