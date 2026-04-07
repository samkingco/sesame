import { animate, circOut } from "motion";

const SEED_OFFSET = 150;
const SEED_STAGGER = 100;
const HERO_STAGGER = 300;
const CONTENT_DELAY = 800;

export async function runIntro() {
  const container = document.querySelector<HTMLElement>(".logo-container");
  const spinGroup = document.getElementById("spin-group");
  const heroLines = document.querySelectorAll<HTMLElement>(".hero-line");
  const belowHero = document.getElementById("below-hero");

  if (!container || !spinGroup) return;

  const seeds = Array.from(
    spinGroup.querySelectorAll<SVGPathElement>("path[data-angle]"),
  ).sort((a, b) => +(a.dataset.angle ?? 0) - +(b.dataset.angle ?? 0));

  // Setup: hide seeds at radial offsets
  spinGroup.setAttribute("transform", "rotate(0, 564, 564)");
  for (const seed of seeds) {
    const deg = +(seed.dataset.angle ?? 0);
    const rad = (deg * Math.PI) / 180;
    animate(
      seed,
      { x: Math.sin(rad) * SEED_OFFSET, y: -Math.cos(rad) * SEED_OFFSET, opacity: 0, filter: "blur(20px)" },
      { duration: 0 },
    );
  }

  // Container is hidden by CSS — show it now that seeds are individually hidden
  container.style.opacity = "1";
  await delay(500);

  // Phase 1: Seeds enter
  await staggerAll(seeds, (seed) =>
    animate(seed, { x: 0, y: 0, opacity: 1, filter: "blur(0px)" }, { duration: 0.4, ease: circOut }),
  SEED_STAGGER);

  // Phase 2: Hero text enters (parallel with spin)
  staggerAll(heroLines, (line) =>
    animate(line, { opacity: [0, 1], filter: ["blur(16px)", "blur(0px)"], y: [20, 0] }, { duration: 0.6, ease: circOut }),
  HERO_STAGGER);

  // Phase 3: Below-hero content enters
  if (belowHero) {
    delay(CONTENT_DELAY).then(() =>
      animate(belowHero, { opacity: [0, 1], y: [30, 0] }, { duration: 0.8, ease: circOut }),
    );
  }

  // Phase 4: Spin (already running in parallel)
  await animate(0, 180, {
    type: "spring",
    stiffness: 100,
    damping: 15,
    mass: 0.8,
    onUpdate: (deg: number) => {
      spinGroup.setAttribute("transform", `rotate(${deg}, 564, 564)`);
    },
  });

  // Cleanup
  window.__introPlayed = true;
  delete document.documentElement.dataset.intro;
  document.getElementById("intro-styles")?.remove();
}

function staggerAll<T extends Element>(
  elements: ArrayLike<T>,
  fn: (el: T) => Promise<any> | any,
  stagger: number,
): Promise<void> {
  return Promise.all(
    Array.from(elements).map(
      (el, i) => new Promise<void>((resolve) => {
        setTimeout(async () => { await fn(el); resolve(); }, i * stagger);
      }),
    ),
  ).then(() => {});
}

function delay(ms: number) {
  return new Promise<void>((r) => setTimeout(r, ms));
}
