# Vindex: Amended Design Document
Supersedes the consolidated notes of 2026-07-19. Incorporates all amendments and added details from the design session of the same date.
Conventions retained from the originals: italics indicate *possible variants*; bold indicates **comments**; AI-written text (Claude's suggestions, accepted or pending) follows a bullet point (-). Unmarked prose states settled design.

---

## I. NATURE OF THE SYSTEM

The Vindex is NOT a decentralized low-trust blockchain. It is a private protocol for the few: an authenticated registry with programmable payouts, run on a permissioned Besu network with QBFT consensus, readable only by participants, at zero gas.

Setting context: this is for an MMO and its Minecraft server digital twin. The chain functions as persistent, tamper-evident cross-world state that neither game server unilaterally owns. The "state," the "reputable institutions," and the Benefactor are game authorities.

- Since validators are few and known and test administration is delegated, the residual requirement is attestation, not trustlessness: each record carries a signature from the administering institution's registered key, so a score cannot be entered by the subject or by a validator acting alone.

---

## II. THE THREE TIERS

You are either a Meritocrat, a citizen, or whatever your local polity's shabby little "government" happens to call whoever lives there.

**All Meritocrats have the same legal rights.** Authority is binary and absolute at the membership boundary; rank within the order is social and reputational, not legal.

To be Crossworld Meritocrat is to be a member of a supraplanetary organization with power and prestige comparable to an Inquisitor, a Rogue Trader, or an Armored Core NEXT. A Meritocrat can:
- order non-meritocrats around;
- requisition resources on demand;
- do whatever they want to places outside the Crossworld Meritocracy.

- The one thing that can strip an otherwise untouchable figure of all authority is a lapsed examination (see §V). Demigods must periodically return and submit to a proctored test like anyone else.
- Requisition wants a chain-side log (who took what, where, under which authority) — costs nothing on this network, and judgements can retroactively contest an abusive requisition even where no external law could.
- The order's only real check on a rogue member is internal: the judgement mechanism doubles as its disciplinary court. Unlike the Inquisitorial archetype, the Vindex has a restraint procedure built into its bones.

---

## III. EXAMINATIONS

### Administration
Merit exams and IQ tests are administered by reputable institutions, and later by the state itself. IQ itself is largely a statement of record.

It is the **Crossworld Merit Examination** and its result that determines whether you are a Meritocrat or not. Surfaced as a bool with an internal cutoff over Merit (M).

### Timing and voluntariness
- The citizens exam can be taken at any time, but is generally administered at 14.
- The meritocrat exam is generally taken at 16 — or 17, or 18, or whenever really. Just depends on you how soon you wanna get on with it.
- The meritocrats exam is **completely optional** if you just wanna be a pleb and not someone who represents the superstate.

- Optional examination changes what the status signals: capability conjoined with consent to serve. Plebs are not failures; they are civilians. Flexible timing removes the tournament structure at age 16; a late examinee loses nothing but time.
- The 14/16 sequencing implies the citizen exam is a prerequisite gate; the preparation window between them is where residual dynastic pressure (tutoring, cram schools, patronage) concentrates. The wealth channel is closed (§VI); the cultural channel remains open, and that is where the world's residual inequality lives.

### Contest and sanction
- The exam can be contested if you find errors in it, which invokes a high commission.
- Prospective meritocrats caught cheating end up in PvP with the admins.
- Examiners who put false questions or genuinely misgrade a meritocrat are subjected to even higher scrutiny, in part administered by an ASI covertly shepherding the system as a whole.

- The escalation gradient is calibrated to trust held, not act committed: a cheating candidate betrays only their own application; a fraudulent examiner corrupts the measurement instrument the whole order rests on. Contestability is what makes the exam a legitimacy-bearing institution rather than a hazing ritual.
- Mechanically: an ordinary judgement that, on success, triggers a superjudgement with a different jury pool and higher stakes.
- The ASI terminates the who-measures-the-measurers regress. Its covert channel should be influence through ordinary means (calibrating question banks, nudging commission appointments, unremarkable sockpuppet members) rather than a hidden root key — slower, but leaves no cryptographic fingerprint; discovery-through-statistical-anomaly is the better mystery hook.

---

## IV. THE RECORD

### Mandatory annual retesting
Retesting is mandatory, kind of like an annual medical checkup. The system stores the array of ALL historical IQ tests taken.

```solidity
struct IqTest {
    uint16 score;
    uint16[] subscores;
    uint64 testDate;        // Unix timestamp
    address institution;    // must be in approved registry
}

mapping(address => IqTest[]) private iqHistory;
```

The institution tag is an address (or index into an on-chain registry of approved institutions), not a free string — the membership votes institutions in and out using the existing judgement mechanism.

`getIq()` returns either the average or the latest score as a shorthand.

- The average/latest choice is policy, not shorthand: latest favours the young; raw averages anchor members to early results and, over twenty annual tests, barely move. *Middle path: recency-weighted average (exponential decay over testDate), or expose both `latestIq()` and `averageIq()` and let each judgement type specify which it consumes.*
- testDate must be validated as monotonically increasing per member on insert, or recency logic can be gamed by backdating.
- Institutions administering annually need alternate forms, or practice effects inflate scores a few points per cycle.

### Staleness enforcement
- The contract cannot compel a test; it enforces the mandate as a staleness check. Every function that consumes merit verifies the latest test is under a year old:

```solidity
function isCurrent(address member) public view returns (bool) {
    IqTest[] storage h = iqHistory[member];
    if (h.length == 0) return false;
    return block.timestamp - h[h.length - 1].testDate <= 365 days;
}
```

- A lapsed member is not expelled, merely inert until they retest — no judgement, no vote, no discretion. *Grace period beyond 365 days*, so members are not disenfranchised mid-judgement by a boundary tick; grace logic must also cover registry churn (an institution voted out mid-cycle must not strand members past deadline through no fault of their own).
- **Known tension, possibly intended:** fluid scores decline with age while seniority weight grows. Under latest-score this builds a counterweight (the old have voice, the young have certified capability) — and a predictable coalition of older members with a shared interest in weakening the retest rule through the very channels their seniority dominates. The likely pressure point is not the entry bar but the aggregation rule and the staleness gate.

### Status predicate

```solidity
uint256 public meritCutoff;  // adjustable by judgement

function isMeritocrat(address member) public view returns (bool) {
    return merit[member] >= meritCutoff && isCurrent(member);
}
```

- Computed on read, not stored: if the cutoff moves (which the constitution allows, by consent of the meritocrats), a derived predicate re-evaluates automatically. *Alternative: sticky status stored at examination time, cutoff governing new admissions only.* Derived status produces churn at the boundary; sticky status produces grandfathered cohorts. Players will notice and exploit either; choose deliberately and document.
- The bool doubles as the privacy gradient: outsiders and lower tiers query the bool; exact M, subscores, and history stay access-restricted. This satisfies "the chain can only be read by agents" without heavy cryptography.
- Internal rankings within the meritocracy: *an ordered set of cutoffs rather than one, each adjustable by judgement* — tiers/titles/brackets over M, governing intra-order matters only (staking weight, bidding precedence, voice in cutoff and admission votes). Legal rights stay flat.

---

## V. THE JUDGEMENT MODULE
*(carried forward from the 2026-07-17 specification, unamended)*

- Judgement pot is opened (*with a small amount of M/V*). A time limit starts.
- Users stake a fixed amount of M/V into the pot to make a yes/no vote. (*Users with higher M can stake more.*) (*Users can pass their voting rights on to other trusted users.*) (*Only a randomly selected jury of users votes*.)
- When the time limit completes, or all users have voted, the majority wins.
- The pot is divided out among the winners *according to how much M they staked.*

**This is the Schelling point incentive used by Kleros to discourage biased voting.**

Tasks, contract bidding, and validator election proceed as previously specified: proposal → acceptance judgement → uptake → completion judgement → reward and record. Validators are elected by reputation-weighted vote, term-limited or rotating; commit-reveal voting, community full nodes, and a documented censorship-eviction process stand as mitigations. (QBFT fault threshold is (n-1)/3.)

---

## VI. THE DEATH TAX

The inheritance tax (the **Death Tax**) is **100%**.

Deathbed conveyance does not count. It is blatant tax evasion; most people understand this. Nor do people leave the polity to die elsewhere — they would lose the benefits of the superior system they were reared in.

Meritocrat status is the one thing money can't buy anyways, and is infinitely more valuable than merely having things.

- The exam and the tax are complementary halves of one claim: status is neither inherited nor imposed, only chosen and earned. The exam is the true anti-dynasty mechanism (wealth cannot convert into status at the boundary that matters); the tax handles the residue, so even raw purchasing power resets each generation. Belt and braces. The successful evader is not a system failure but a pitiable figure who cheated to retain the lesser prize.
- Enforcement load rests on two pillars: on-chain wealth legibility (lifetime transfers visible as no historical tax authority ever achieved) and the ASI-backed scrutiny apparatus. Norms at the top hold because detection is likely and sanction credible — an achievement of architecture plus culture, and the place a story about a would-be dynast applies pressure.
- Destination of escheated estates: *the treasury*. Death is the funding mechanism — judgement pots, task rewards, and new-member issuance denominated against a treasury that refills every generation. This answers the original open question of whether the meritocracy has public funds.
- Terminal-phase incentive: with nothing to bequeath, the rational elder converts wealth into the one estate the tax cannot touch — reputation within the order. Senior Meritocrats pouring fortunes into staking, patronage, and monuments is the intended structural effect: **the Death Tax makes M the only durable estate.**

---

## VII. OPEN ITEMS

1. Aggregation rule for `getIq()`: latest, average, or decay-weighted — and per-judgement-type selection.
2. Sticky vs derived Meritocrat status at cutoff changes.
3. Grace-period constants for staleness and registry churn.
4. Concrete tier ladder over M for internal rankings (sentence left unfinished in session; primitive agreed: ordered cutoffs adjustable by judgement).
5. Requisition log schema and the judgement type that contests an entry.
6. Whether the citizen exam is formally prerequisite to the Crossworld Merit Examination or merely customary.
7. The ASI's in-fiction discovery conditions.
