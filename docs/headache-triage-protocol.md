# Headache triage protocol

Andrii Yevenko · October 2026 · based on NCBI sources (PubMed, PMC, Bookshelf) and NICE CG150

Implemented in [`cql/HeadacheTriage.cql`](../cql/HeadacheTriage.cql) and checked by test scenarios `h01`–`h25` in [`scenarios/`](../scenarios/). The escalation levels are illustrative: this demonstrates an approach, not a clinical recommendation.

## Purpose and scope

The protocol assigns a patient's headache report to one of the engine's levels (ED, Emergency, Urgent, No escalation) or asks for missing data. It does not diagnose: its job is not to miss a secondary headache.

- **Where it runs:** remote monitoring and a patient chat. Input: the patient's own report plus profile data (age, pregnancy, cancer history, immunosuppression).
- **Who it covers:** adults, 18 and older. Children have different red flags and need a separate protocol.
- **What it does not do:** classify a primary headache, recommend medicines or replace an examination.
- **Main principle:** the decision rests on how the pain started and on the signs that come with it, not on the pain score. The score is a lower-priority criterion.

## Levels and branch priority

Branches are checked top-down and the first true one wins. Any positive flag outranks both an incomplete screen and the pain score.

| Order | What fired | Proposed Level | Disposition | Response (proposed) |
|---|---|---|---|---|
| 1 | Suspected carbon monoxide | ED escalation | Leave area and seek emergency care | Immediately; leave the building first |
| 2 | Any red flag | ED escalation | Emergency Department evaluation | Immediately |
| 3 | At least one ED-level question unanswered | The highest orange flag so far, or null | Ask headache screen | Answer the rest; if the level is not null, the care team is already alerted |
| 4 | An Emergency-level flag | Emergency escalation | Provider evaluation required | Seen by a doctor the same day |
| 5 | An Urgent-level flag, or NRS ≥ 8 | Urgent escalation | Provider notification | Contact from the care team within a day |
| 6 | A question that can still change the level is unanswered, no flags | null | Ask headache screen | Answer the remaining questions |
| 7 | Screen complete, NRS 0–7 | No escalation required | Reassure | Self-care and when to seek help again |
| 8 | Screen complete, no pain score | null | Ask pain score | Rate the pain |

When several flags fire, the highest one sets the level. Every flag that fired is returned as a separate output, **Fired Flags**: the alert text for the care team needs it.

## Red flags → ED escalation

Any of these flags in the window gives ED, even if the other answers are unknown. Signs that only an examination can show (papilloedema, limited neck flexion on examination) are not available remotely and are not part of the rule.

| Flag | Question to the patient | Local code | Source |
|---|---|---|---|
| Suspected carbon monoxide | Does anyone around you have similar symptoms? Is a generator, gas heater or stove running indoors? | `co-exposure` | StatPearls, Carbon Monoxide Poisoning: headache is the most common symptom; similar symptoms in several people in one building should raise suspicion |
| Thunderclap onset | How quickly did the headache reach its worst? → within 5 minutes | `onset-peak` = `within-5-min` | NICE CG150, 1.1.1; StatPearls, Thunderclap Headache: the two most common secondary causes are SAH and RCVS |
| New neurological deficit | Weakness or numbness on one side, trouble speaking, a drooping face, double vision or loss of vision, a seizure? | `neuro-deficit` | NICE CG150, 1.1.1 |
| Altered consciousness or behaviour | Confusion, unusual drowsiness, fainting, or a change in behaviour noticed by others? | `altered-consciousness` | NICE CG150, 1.1.1: cognitive dysfunction, personality change, impaired consciousness |
| Fever with neck pain or stiffness | Do you have a fever? Is your neck painful or stiff? | `fever` + `neck-stiffness` | StatPearls, Bacterial Meningitis: the full triad in only 41%; van de Beek 2004: 95% have at least 2 of 4 signs |
| Ottawa SAH Rule | New pain, peak within an hour, NRS ≥ 7, plus any of: age ≥ 40, neck pain or stiffness, witnessed loss of consciousness, onset during exertion | `onset-peak` = `5-to-60-min` + `similarity` ≠ `usual` + one criterion | Perry 2013: sensitivity 100%, specificity 15.3% |
| Acute angle-closure glaucoma | Is an eye painful or red? Is your vision blurred, or do you see rainbow rings around lights? | `eye-pain-vision` | NICE CG150, 1.1.1; StatPearls, Acute Angle-Closure Glaucoma |

A separate question defines “new” pain: is this headache like your usual headaches (first ever / different from usual / like usual)? The Ottawa SAH Rule was derived in the ED on alert patients with a normal neurological examination, so without an examination it performs worse than in the study. Confusion without fever already gives ED through “altered consciousness”, so the meningitis branch needs only fever and neck symptoms.

## Orange flags → Emergency or Urgent

These signs do not need an ambulance but do need a doctor: the same day (Emergency) or within a day (Urgent). NICE phrases them as “assess and consider investigation or referral”; SNNOOP10 lists them as signs of a possible secondary headache.

| Flag | Level | Question or fact | Local code | Source |
|---|---|---|---|---|
| Fever and the headache is getting worse | Emergency | Do you have a fever? Is the headache getting worse? | `fever` + `worsening` | NICE CG150, 1.1.1 |
| Pregnancy or postpartum + new or unusual headache | Emergency | Profile; similarity to usual headaches | `pregnancy-or-postpartum` | StatPearls, Postpartum Headache: pre-eclampsia, venous sinus thrombosis, RCVS; pre-eclampsia can start after birth, usually on days 7–10 |
| Age ≥ 50, new or changed headache + jaw pain when chewing or a tender scalp | Emergency | Does your jaw hurt when you chew? Is your scalp sore to the touch? | `gca-features` | StatPearls, Giant Cell Arteritis: visual symptoms in 20–30% of patients |
| Head injury in the last 3 months | Emergency | Have you hit your head recently? When? | `head-trauma` | NICE CG150, 1.1.1; SNNOOP10 |
| Immunosuppression (HIV, immunosuppressive drugs) + new headache | Emergency | Profile | `immunocompromised` | NICE CG150, 1.1.2; SNNOOP10 |
| New headache (first ever), or a marked change from the usual | Urgent | Similarity = first ever or different | `similarity` | SNNOOP10: pattern change or recent new headache; NICE CG150, 1.1.1 |
| Progressive headache + new or changed headache | Urgent | Is it getting worse from day to day? | `progressive` | SNNOOP10: progressive headache; NICE CG150, 1.1.1 |
| Headache that changes with posture + new or changed headache | Urgent | Does it change when you lie down or stand up? | `positional` | NICE CG150, 1.1.1; SNNOOP10: intracranial hyper- or hypotension |
| Headache triggered by coughing, sneezing, straining or exercise + new or changed headache | Urgent | Does it start or get worse when you cough, sneeze, strain or exert yourself? | `valsalva-exertion` | NICE CG150, 1.1.1 |
| History of cancer (one that spreads to the brain) + new headache | Urgent | Profile | `cancer-history` | NICE CG150, 1.1.2 |
| Vomiting + new headache | Urgent | Have you vomited? | `vomiting` | NICE CG150, 1.1.2: vomiting without another obvious cause |

Positional, cough-triggered and progressive features count only with a new or changed headache (owner decision, October 2026): with a headache like the usual ones they are not flags and are not asked. A new or changed headache is already Urgent, so these features, like vomiting and a cancer history, add detail to the alert but do not change the level.

Loss of vision or double vision with suspected GCA already gives ED through “new neurological deficit”. NICE gives a migraine attack as an example of an “other obvious cause” of vomiting, but a patient cannot tell the difference, so the rule counts vomiting with any new headache.

## Intensity, missing data and Ask

The pain score affects the decision only when the screen is complete and no flag fired. NICE describes migraine pain as moderate or severe and cluster headache as severe or very severe, so a high score alone does not tell a primary headache from a secondary one.

- NRS ≥ 8 → Urgent: a person in severe pain needs a pain-relief plan, not an ambulance.
- NRS 0–7 → No escalation required, Disposition = Reassure.

**Which questions are asked.** The rule itself returns **Questions Needed**: the unanswered questions whose answer can still change the level, in the order to ask them. The chat asks the first one, runs the rule again and repeats, so a question is never asked when no answer to it could change the advice.

| Question | Asked when |
|---|---|
| `co-exposure`, `onset-peak`, `similarity`, `neuro-deficit`, `altered-consciousness`, `fever`, `neck-stiffness`, `eye-pain-vision` | Always: ED-level, asked first |
| `onset-exertion` | Only for the Ottawa branch: a new or changed headache that peaked in 5–60 minutes, age under 40 and no stiff neck (otherwise the rule is already met or cannot apply) |
| Pain score (NRS) | ED-level in the Ottawa branch; otherwise only while no orange flag has fired, because it then decides between Reassure and Urgent |
| `head-trauma` | While the level is below Emergency |
| `worsening` | Only after “Yes” to fever, while the level is below Emergency |
| `gca-features` | Age ≥ 50 and a new or changed headache, while the level is below Emergency |
| `positional`, `valsalva-exertion`, `progressive`, `vomiting` | Never: they count only with a new or changed headache, which is already Urgent, so they cannot change the level |

**Stopping early** (owner decision, October 2026). Nothing more is asked once the level is ED, or once it is Emergency and every ED-level question is answered: the remaining answers could not change the advice. The alert then lists only the flags found so far. A typical headache like the usual ones takes 10 questions instead of 16.

- **“No” is a fact.** Each question is recorded as its own Observation with a yes/no answer. A flag fires only on “Yes”, and a question counts as answered only when it has a value. This closes two gaps of a plain “symptom present” model: an Observation without a value is not an answer, and a symptom answered “No” does not escalate.
- **“Prefer not to answer”** (“Not sure” in the chat) means no answer.
- **Ask Headache Screen** = true when Questions Needed is not empty. **Ask Pain Score** = true when there is no pain score in the window.
- **Proposed Level** = null only when no flag fired and an answer is missing. A positive flag does not wait for the screen to finish.

Unlike a rule where only a pain score can be missing (and a missing score can never outrank a red flag), here unanswered questions can still reveal ED. So the ED-level questions come first, and while any of them is unanswered, Disposition = Ask headache screen, even if New Level has already sent the care team an Emergency or Urgent alert.

## Patient texts for the Disposition

| Disposition | Text on the page |
|---|---|
| Emergency Department evaluation | Unchanged |
| Provider evaluation required | Unchanged |
| Provider notification | Unchanged |
| Ask pain score | Unchanged |
| Reassure | Includes when to seek help again: sudden worsening of the pain, weakness, numbness, trouble speaking, confusion or a seizure |
| Leave area and seek emergency care (new) | Your symptoms could be caused by carbon monoxide. Get everyone, including pets, out into fresh air now. Call emergency services from outside. Do not go back in until the building has been checked. |
| Ask headache screen (new) | We need a few more answers before we can advise you. Please answer the remaining questions. If your headache suddenly becomes severe, or you notice weakness, numbness, trouble speaking, confusion or a seizure, call emergency services now. |

The text for “Ask headache screen” deliberately includes a short ED reminder: the patient may not reach the end of the questions.

## How it maps to the engine

The rule is `cql/HeadacheTriage.cql`; it includes `RulePatterns` and has the same output contract as the other modules (Proposed Level, New Level, Disposition).

| What | In the engine |
|---|---|
| Headache present | Observation SNOMED CT 25064002 (Headache) answered “Yes” in the window; without it every output is null and the rule does not apply |
| Pain score | LOINC 72514-3 (pain severity, 0–10 verbal numeric rating); the latest answered score in the window counts |
| Screening questions | One Observation per question: code `urn:example:cql-demo:headache` + slug, `valueCodeableConcept` = LOINC LA33-6 (Yes) or LA32-8 (No) |
| Time to peak | `onset-peak` with three local answers: `within-5-min`, `5-to-60-min`, `over-60-min` |
| Similarity to usual headaches | `similarity`: `first-ever`, `different`, `usual` |
| Age | `AgeInYears()` from `Patient.birthDate`; a scenario gives it as `birthDate` or as a whole `patient` resource |
| Pregnancy, immunosuppression, cancer history | Profile facts: Observations with code `urn:example:cql-demo:profile` + slug, source MANUAL or Patient. In the demo they come from the **Patient background** tab |
| “New” headache | The similarity answers that make a headache new (`first-ever`, `different`) form a ValueSet in `vocabulary.json` |
| Flags | One `define` per flag, plus `Severe Pain` for NRS ≥ 8. They are not ValueSets: most of them combine answers (fever + neck, Ottawa, age ≥ 50 + new pain) |

New building blocks in `RulePatterns`:

- **Answered / Answered Yes.** A fact becomes a flag only with the value Yes, and an answer only when it has a value.
- **From Record.** Profile facts also accept MANUAL, because a clinician enters them. Symptoms and answers are still accepted only from Patient and RPM.
- **Dated Within(lookback).** The head-injury answer is recorded at the time of the conversation, and the date of the injury is its value (`valueDateTime`). The flag fires when that date is no older than 90 days. Symptoms stay in `Conversation Window(Last Run, 12 h)`.

Outputs: Proposed Level, New Level (through Monotonic Escalation), Disposition, Ask Headache Screen, Ask Pain Score, **Questions Needed** — the questions still worth asking, in order — and **Fired Flags** — the list of codes of the flags that fired, for the alert text.

## Test scenarios

Twenty-five scenarios cover every branch, every boundary (NRS 7/8, age 39/40 and 49/50, injury 90/91 days ago), missing data, an untrusted source, the choice of the latest pain score and the question tree. The base for all of them: headache “yes” in the window, every question “no”, similarity “like usual”, NRS 5, age 35, an empty profile, source Patient, Last Run and Current Level null.

| # | Change from the base | Proposed Level | Disposition | What it checks |
|---|---|---|---|---|
| H01 | None | No escalation required | Reassure | The base path |
| H02 | NRS 7 | No escalation required | Reassure | The NRS boundary from below |
| H03 | NRS 8 | Urgent escalation | Provider notification | The NRS boundary |
| H04 | `onset-peak` = `within-5-min` | ED escalation | Emergency Department evaluation | Thunderclap onset |
| H05 | Onset 5–60 min, first ever, NRS 7, age 40 | ED escalation | Emergency Department evaluation | Ottawa, the age boundary |
| H06 | As H05, but age 39 | Urgent escalation | Provider notification | Ottawa does not fire; “new pain” remains |
| H07 | Onset 5–60 min, first ever, age 45, no NRS | Urgent escalation | Ask headache screen | The NRS becomes an ED-level question |
| H08 | Fever + neck stiffness | ED escalation | Emergency Department evaluation | The meningitis branch |
| H09 | Fever + worsening, neck “no” | Emergency escalation | Provider evaluation required | NICE: fever with a worsening headache |
| H10 | `co-exposure` + `within-5-min` | ED escalation | Leave area and seek emergency care | CO outranks the other ED branches |
| H11 | Age 50, first ever, `gca-features` “yes” | Emergency escalation | Provider evaluation required | GCA, the age boundary |
| H12 | Age 49, first ever, `gca-features` “yes” | Urgent escalation | Provider notification | The GCA branch is off below 50 |
| H13 | Head injury 90 days ago | Emergency escalation | Provider evaluation required | The injury window boundary |
| H14 | Head injury 91 days ago | No escalation required | Reassure | A fact outside the window has no effect |
| H15 | `neuro-deficit` as an Observation without a value | null | Ask headache screen | An empty Observation is not an answer |
| H16 | `neuro-deficit` “yes”, other questions unanswered | ED escalation | Emergency Department evaluation | A flag does not wait for the full screen; nothing more is asked |
| H17 | Head injury 2 weeks ago, `eye-pain-vision` unanswered | Emergency escalation | Ask headache screen | An orange flag with ED questions incomplete: only the ED question is still needed |
| H18 | `neuro-deficit` “yes” from source MANUAL | null | Ask headache screen | A clinician's entry is not the patient's answer |
| H19 | Immunosuppression in the profile (MANUAL), first ever | Emergency escalation | Provider evaluation required | From Record accepts MANUAL for the profile |
| H20 | Current Level = ED escalation, `within-5-min` | ED escalation | Emergency Department evaluation | New Level = null, no repeat alert |
| H21 | Two pain scores: 9 earlier, 4 now | No escalation required | Reassure | The latest score counts, not the highest |
| H22 | Usual headache, age 55; exertion, worsening, posture, cough, day-to-day, vomiting and GCA unanswered | No escalation required | Reassure | None of those questions is needed for a usual headache |
| H23 | Different headache, immunosuppressed; nothing after the ED questions | Emergency escalation | Provider evaluation required | Emergency with the ED questions answered stops the screen |
| H24 | Fever “yes”, neck “no”, worsening unanswered | null | Ask headache screen | Fever makes the worsening question needed |
| H25 | First headache like this, peak in 5–60 minutes, age 35 | Urgent escalation | Ask headache screen | The Ottawa branch makes exertion and the pain score ED-level questions |

H15, H17 and H18 also check Ask Headache Screen = true; H16, H17 and H22–H25 check Questions Needed; H20 checks New Level = null. Every base answer is an explicit “No”, so each scenario also checks that “No” never raises a flag.

## Owner decisions and evidence limits

The protocol is deliberately sensitive: most flags have low specificity on their own, and for the Ottawa SAH Rule it is 15.3%. There will be many escalations, so the share of justified ones should be measured in a pilot. The implementation follows the “Now in the protocol” column.

| Question | Now in the protocol | Alternative |
|---|---|---|
| Thunderclap threshold | Within 5 minutes, as in NICE | “Instantly”, within 1 minute, as in Ottawa; fewer false ED escalations |
| “Severe” pain in the Ottawa branch | NRS ≥ 7 | No threshold: more sensitive, but more ED |
| NRS ≥ 8 without flags | Urgent | Emergency; a PMC review lists high intensity among red flags |
| New headache in a young patient with no other signs | Urgent | No escalation with advice; SNNOOP10 counts it as a flag |
| Typical aura in a patient with known migraine with aura | ED, as a neurological deficit | Do not count it if the aura is the same as always; NICE describes typical aura as fully reversible, developing over at least 5 minutes and lasting 5–60 minutes |
| Head injury on anticoagulants | Emergency, like any injury | ED; check against NICE NG232 |
| Immunosuppression + new headache | Emergency | Urgent: NICE phrases it as “consider investigation” |
| Pregnancy | From the profile only | Ask all women of childbearing age; define the postpartum period and a blood-pressure threshold if RPM sends blood pressure |
| Medication overuse (SNNOOP10) | Does not escalate | A separate output for a routine review |
| “Don't know” on an ED-level question | As a missing answer → Ask | As “yes”, fail-safe, like PHQ-9 item 9 |
| Positional, cough-triggered or progressive features with a headache like the usual ones | Not flags, not asked (decided October 2026) | Urgent flags with any headache, as in SNNOOP10: more sensitive, three more questions; a slowly growing secondary headache can feel “usual” to the patient |
| Questions after the level can no longer change | Not asked (decided October 2026) | Ask everything so that the alert lists every flag |

**Evidence limits.**

- Every source describes a face-to-face assessment. Signs that only an examination shows (papilloedema, neck stiffness on examination, limited neck flexion) are missing here, so sensitivity is lower than in the studies.
- The Ottawa SAH Rule was validated in the ED on patients with a normal neurological examination; here it relies on a self-report.
- The NCBI pages could not be opened directly (a bot check). The wording was checked against search excerpts of those pages and against the same NICE recommendations on nice.org.uk. Before production, check against the full texts.

## Sources

All from NCBI (PubMed, PMC, Bookshelf) unless stated otherwise.

- Do TP et al. Red and orange flags for secondary headaches in clinical practice: SNNOOP10 list. *Neurology*, 2019.
- Secondary headaches: red and green flags and their significance for diagnostics (review).
- NICE CG150. Headaches in over 12s: diagnosis and management.
- Perry JJ et al. Clinical decision rules to rule out subarachnoid hemorrhage for acute headache. *JAMA*, 2013.
- StatPearls. Thunderclap Headache.
- StatPearls. Giant Cell Arteritis (Temporal Arteritis).
- StatPearls. Postpartum Headache.
- StatPearls. Carbon Monoxide Poisoning.
- StatPearls. Bacterial Meningitis.
- van de Beek D et al. Clinical features and prognostic factors in adults with bacterial meningitis. *NEJM*, 2004.
- StatPearls. Acute Angle-Closure Glaucoma.
- NICE NG232. Head injury: assessment and early management (only for the open question about anticoagulants).
