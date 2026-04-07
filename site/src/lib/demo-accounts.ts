import { generateSecret, base32Encode, buildOTPAuthURI } from "./totp";

const STORAGE_KEY = "sesame-demo-accounts";
const MAX_ACCOUNTS = 5;

export interface DemoAccount {
  id: string;
  name: string;
  jobTitle: string;
  email: string;
  secret: string;
  otpAuthURI: string;
}

// Sesame-themed first names (seeds, grains, pastes)
const FIRST_NAMES = [
  "Sim",
  "Tahini",
  "Halva",
  "Nori",
  "Miso",
  "Goma",
  "Poppy",
  "Flax",
  "Chia",
  "Saffron",
  "Basil",
  "Quinoa",
  "Mochi",
  "Tofu",
  "Koji",
  "Tamari",
  "Umami",
  "Wasabi",
  "Matcha",
  "Sencha",
];

const LAST_NAMES = [
  "Hull",
  "Mortar",
  "Pestle",
  "Stone",
  "Mill",
  "Press",
  "Roast",
  "Grind",
  "Drizzle",
  "Sprout",
  "Harvest",
  "Fields",
  "Bloom",
  "Thresh",
  "Silo",
  "Furrow",
  "Acre",
  "Grove",
  "Meadow",
  "Vale",
];

const JOB_TITLES = [
  "CEO",
  "CTO",
  "CFO",
  "VP of Procurement",
  "Head of Blending Ops",
  "Chief Seed Officer",
  "Director of Grinding",
  "Lead Paste Engineer",
  "Senior Roast Analyst",
  "Sesame Sommelier",
  "Quality Assurance",
  "Head of R&D",
  "Supply Chain Lead",
  "Flavor Architect",
  "Harvest Coordinator",
];

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function generateId(): string {
  return crypto.randomUUID().slice(0, 8);
}

const PENDING_KEY = "sesame-demo-pending";

export function createAccount(): DemoAccount {
  const firstName = pick(FIRST_NAMES);
  const lastName = pick(LAST_NAMES);
  const name = `${firstName} ${lastName}`;
  const jobTitle = pick(JOB_TITLES);
  const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}@gomashio.co`;
  const secretBytes = generateSecret();
  const secret = base32Encode(secretBytes.buffer);
  const otpAuthURI = buildOTPAuthURI(email, secret);

  return { id: generateId(), name, jobTitle, email, secret, otpAuthURI };
}

export function getOrCreatePendingAccount(): DemoAccount {
  try {
    const raw = localStorage.getItem(PENDING_KEY);
    if (raw) return JSON.parse(raw) as DemoAccount;
  } catch {
    // fall through
  }
  const account = createAccount();
  localStorage.setItem(PENDING_KEY, JSON.stringify(account));
  return account;
}

export function clearPendingAccount(): void {
  localStorage.removeItem(PENDING_KEY);
}

export function getAccounts(): DemoAccount[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as DemoAccount[];
  } catch {
    return [];
  }
}

export function getAccount(id: string): DemoAccount | undefined {
  return getAccounts().find((a) => a.id === id);
}

export function saveAccount(account: DemoAccount): void {
  const accounts = getAccounts().filter((a) => a.id !== account.id);
  accounts.unshift(account);
  localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify(accounts.slice(0, MAX_ACCOUNTS)),
  );
}
