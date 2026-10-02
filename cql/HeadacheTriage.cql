library HeadacheTriage version '0.1.0'

// Headache triage for adults (18+), based on NICE CG150, SNNOOP10, the Ottawa SAH Rule and StatPearls.
// It does not diagnose: its job is not to miss a secondary headache. The decision rests on how the pain
// started and on the signs that come with it, not on the pain score; the score is a lower-priority criterion.
// Branches are checked top-down and the first true one wins. Any positive flag outranks both an incomplete
// screen and the pain score. The rule also decides which questions are still needed: only those whose answer
// can still change the level. Escalation levels are illustrative for the demo, not a clinical recommendation.

using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers
include RulePatterns version '0.1.0' called Patterns

codesystem "LOINC": 'http://loinc.org'
codesystem "SNOMED": 'http://snomed.info/sct'
codesystem "Headache": 'urn:example:cql-demo:headache'
codesystem "Profile": 'urn:example:cql-demo:profile'
codesystem "Answer": 'urn:example:cql-demo:answer'

code "Headache finding": '25064002' from "SNOMED" display 'Headache'
code "Pain severity 0-10": '72514-3' from "LOINC" display 'Pain severity - 0-10 verbal numeric rating [Score] - Reported'

// Screening questions: one Observation per question, answered Yes / No (LOINC LA33-6 / LA32-8)
code "CO exposure": 'co-exposure' from "Headache"
code "Onset to peak": 'onset-peak' from "Headache"
code "Onset on exertion": 'onset-exertion' from "Headache"
code "Similarity": 'similarity' from "Headache"
code "Neuro deficit": 'neuro-deficit' from "Headache"
code "Altered consciousness": 'altered-consciousness' from "Headache"
code "Fever question": 'fever' from "Headache"
code "Neck stiffness": 'neck-stiffness' from "Headache"
code "Eye pain or vision": 'eye-pain-vision' from "Headache"
code "Worsening": 'worsening' from "Headache"
code "Head trauma": 'head-trauma' from "Headache"
code "Positional question": 'positional' from "Headache"
code "Valsalva or exertion": 'valsalva-exertion' from "Headache"
code "Progressive question": 'progressive' from "Headache"
code "Vomiting": 'vomiting' from "Headache"
code "GCA features": 'gca-features' from "Headache"

// Patient background
code "Pregnancy or postpartum": 'pregnancy-or-postpartum' from "Profile"
code "Immunocompromised": 'immunocompromised' from "Profile"
code "Cancer history": 'cancer-history' from "Profile"

// Answers that are not yes/no
code "Within 5 min": 'within-5-min' from "Answer"
code "5 to 60 min": '5-to-60-min' from "Answer"

// Answers that make a headache "new": the first one like this, or different from the usual ones
valueset "New or changed headache": 'urn:example:cql-demo:valueset:new-or-changed-headache'

parameter "Last Run" DateTime
parameter "Current Level" String

context Patient

// ---------- scope ----------

define "Window":
  Patterns."Conversation Window"("Last Run", 12 hours)

define "Age":
  AgeInYears()

define "Headache Reported":
  exists Patterns."Answered Yes"(Patterns."In Window"(Patterns."From Patient"([Observation: "Headache finding"]), "Window"))

// Adults only; an unknown age does not block triage
define "Applies":
  "Headache Reported" and Coalesce("Age" >= 18, true)

// ---------- answers ----------

// The patient's own answers to a question in this conversation
define function "Answers"(obs List<Observation>):
  Patterns."In Window"(Patterns."From Patient"(obs), "Window")

define function "Was Answered"(obs List<Observation>):
  exists Patterns."Answered"("Answers"(obs))

define function "Said Yes"(obs List<Observation>):
  exists Patterns."Answered Yes"("Answers"(obs))

define function "Answer Of"(obs List<Observation>):
  Patterns."Latest"(Patterns."Answered"(Patterns."From Patient"(obs)), "Window").value as FHIR.CodeableConcept

// Background facts are not tied to the conversation and may come from the clinical record
define function "On Record"(obs List<Observation>):
  exists Patterns."Answered Yes"(Patterns."From Record"(obs))

define "Pain Now":
  (Patterns."Latest"(Patterns."Answered"(Patterns."From Patient"([Observation: "Pain severity 0-10"])), "Window").value as FHIR.Quantity).value

define "Onset Peak":
  "Answer Of"([Observation: "Onset to peak"])

define "Similarity To Usual":
  "Answer Of"([Observation: "Similarity"])

define "New Or Changed Pain":
  "Similarity To Usual" in "New or changed headache"

// ---------- red flags → ED escalation ----------

define "CO Exposure":
  "Said Yes"([Observation: "CO exposure"])

define "Thunderclap":
  "Onset Peak" ~ "Within 5 min"

define "Neuro Deficit":
  "Said Yes"([Observation: "Neuro deficit"])

define "Altered Consciousness":
  "Said Yes"([Observation: "Altered consciousness"])

define "Fever":
  "Said Yes"([Observation: "Fever question"])

define "Neck Stiffness":
  "Said Yes"([Observation: "Neck stiffness"])

define "Onset On Exertion":
  "Said Yes"([Observation: "Onset on exertion"])

// Fever with neck pain or stiffness; confusion alone is already a red flag of its own
define "Meningism":
  "Fever" and "Neck Stiffness"

// Ottawa SAH Rule: new pain peaking within an hour, severe (NRS >= 7), plus any one criterion
define "Ottawa SAH":
  "Onset Peak" ~ "5 to 60 min" and "New Or Changed Pain" and "Pain Now" >= 7
    and ("Age" >= 40 or "Neck Stiffness" or "Altered Consciousness" or "Onset On Exertion")

define "Eye Pain Or Vision":
  "Said Yes"([Observation: "Eye pain or vision"])

define "Red Flag":
  "Thunderclap" or "Neuro Deficit" or "Altered Consciousness" or "Meningism" or "Ottawa SAH" or "Eye Pain Or Vision"

// ---------- orange flags → Emergency escalation ----------

define "Fever And Worsening":
  "Fever" and "Said Yes"([Observation: "Worsening"])

define "Pregnancy Flag":
  "On Record"([Observation: "Pregnancy or postpartum"]) and "New Or Changed Pain"

define "GCA Flag":
  "Age" >= 50 and "New Or Changed Pain" and "Said Yes"([Observation: "GCA features"])

define "Recent Head Trauma":
  exists Patterns."Dated Within"(Patterns."Answered"("Answers"([Observation: "Head trauma"])), 90 days)

define "Immunocompromised Flag":
  "On Record"([Observation: "Immunocompromised"]) and "New Or Changed Pain"

define "Emergency Flag":
  "Fever And Worsening" or "Pregnancy Flag" or "GCA Flag" or "Recent Head Trauma" or "Immunocompromised Flag"

// ---------- orange flags → Urgent escalation ----------

// Owner decision: with a headache like the usual ones these features do not count (and are not asked).
// A new or changed headache is already Urgent, so they add detail to the alert but never change the level.
define "Progressive":
  "Said Yes"([Observation: "Progressive question"]) and "New Or Changed Pain"

define "Positional":
  "Said Yes"([Observation: "Positional question"]) and "New Or Changed Pain"

define "Valsalva Or Exertion":
  "Said Yes"([Observation: "Valsalva or exertion"]) and "New Or Changed Pain"

define "Cancer Flag":
  "On Record"([Observation: "Cancer history"]) and "New Or Changed Pain"

// NRS 8 or more: a pain-relief plan is needed, not an ambulance
define "Severe Pain":
  "Pain Now" >= 8

define "Vomiting Flag":
  "Said Yes"([Observation: "Vomiting"]) and "New Or Changed Pain"

define "Urgent Flag":
  "New Or Changed Pain" or "Progressive" or "Positional" or "Valsalva Or Exertion" or "Cancer Flag" or "Vomiting Flag"

// ---------- which questions are still needed? ----------

// A question is needed only while it is unanswered and its answer can still change the level.
// Once the level is ED nothing is asked; once it is Emergency only the ED-level questions remain.
// The chat asks the first needed question, re-runs the rule and repeats.

// ED-level questions come first. The time to peak and the similarity to usual headaches decide whether
// the Ottawa SAH Rule applies; only then do onset on exertion and the pain score become ED-level.
define "Ottawa Possible":
  "Onset Peak" ~ "5 to 60 min" and "New Or Changed Pain"

define "ED Questions Needed":
  if "CO Exposure" or "Red Flag" then List<System.String>{}
  else (List<System.String> {
    if not "Was Answered"([Observation: "CO exposure"]) then 'co-exposure' else null,
    if not "Was Answered"([Observation: "Onset to peak"]) then 'onset-peak' else null,
    if not "Was Answered"([Observation: "Similarity"]) then 'similarity' else null,
    if not "Was Answered"([Observation: "Neuro deficit"]) then 'neuro-deficit' else null,
    if not "Was Answered"([Observation: "Altered consciousness"]) then 'altered-consciousness' else null,
    if not "Was Answered"([Observation: "Fever question"]) then 'fever' else null,
    if not "Was Answered"([Observation: "Neck stiffness"]) then 'neck-stiffness' else null,
    if not "Was Answered"([Observation: "Eye pain or vision"]) then 'eye-pain-vision' else null,
    // exertion is one of the Ottawa criteria; age 40+ or a stiff neck already meets the rule
    if "Ottawa Possible" and Coalesce("Age" < 40, true) and not "Neck Stiffness"
      and not "Was Answered"([Observation: "Onset on exertion"]) then 'onset-exertion' else null,
    if "Ottawa Possible" and "Pain Now" is null then 'pain-score' else null
  }) Q where Q is not null

// The rest can raise the level to Emergency, or decide between Reassure and Urgent (the pain score).
// Positional, Valsalva, progressive and vomiting count only with a new or changed headache, which is
// already Urgent, so they can never change the level and are never needed.
define "Other Questions Needed":
  if "CO Exposure" or "Red Flag" or "Emergency Flag" then List<System.String>{}
  else (List<System.String> {
    if not "Urgent Flag" and "Pain Now" is null then 'pain-score' else null,
    if not "Was Answered"([Observation: "Head trauma"]) then 'head-trauma' else null,
    if "Fever" and not "Was Answered"([Observation: "Worsening"]) then 'worsening' else null,
    if "Age" >= 50 and "New Or Changed Pain" and not "Was Answered"([Observation: "GCA features"]) then 'gca-features' else null
  }) Q where Q is not null

define "Questions Needed":
  if not "Applies" then null
  else flatten { "ED Questions Needed", "Other Questions Needed" }

define "ED Questions Answered":
  not exists "ED Questions Needed"

define "Other Questions Answered":
  not exists "Other Questions Needed"

define "Ask Headache Screen":
  if not "Applies" then null
  else exists "Questions Needed"

define "Ask Pain Score":
  if not "Applies" then null
  else "Pain Now" is null

// ---------- decision ----------

define "Proposed Level":
  if not "Applies" then null
  else case
    when "CO Exposure" or "Red Flag" then 'ED escalation'
    // an unanswered ED-level question could still reveal ED: report the highest orange flag found so far
    when not "ED Questions Answered" then
      case
        when "Emergency Flag" then 'Emergency escalation'
        when "Urgent Flag" then 'Urgent escalation'
        else null
      end
    when "Emergency Flag" then 'Emergency escalation'
    when "Urgent Flag" or "Severe Pain" then 'Urgent escalation'
    when not "Other Questions Answered" then null
    when "Pain Now" is not null then 'No escalation required'
    else null
  end

define "New Level":
  Patterns."Monotonic Escalation"("Current Level", "Proposed Level")

// What the patient needs now. "New Level" decides whether a new alert goes out.
define "Disposition":
  if not "Applies" then null
  else case
    when "CO Exposure" then 'Leave area and seek emergency care'
    when "Red Flag" then 'Emergency Department evaluation'
    when not "ED Questions Answered" then 'Ask headache screen'
    when "Emergency Flag" then 'Provider evaluation required'
    when "Urgent Flag" or "Severe Pain" then 'Provider notification'
    when not "Other Questions Answered" then 'Ask headache screen'
    when "Pain Now" is not null then 'Reassure'
    else 'Ask pain score'
  end

// Every flag that fired, for the alert text to the care team
define "Fired Flags":
  if not "Applies" then null
  else (List<System.String> {
    if "CO Exposure" then 'co-exposure' else null,
    if "Thunderclap" then 'thunderclap' else null,
    if "Neuro Deficit" then 'neuro-deficit' else null,
    if "Altered Consciousness" then 'altered-consciousness' else null,
    if "Meningism" then 'meningism' else null,
    if "Ottawa SAH" then 'ottawa-sah' else null,
    if "Eye Pain Or Vision" then 'eye-pain-vision' else null,
    if "Fever And Worsening" then 'fever-worsening' else null,
    if "Pregnancy Flag" then 'pregnancy-or-postpartum' else null,
    if "GCA Flag" then 'gca' else null,
    if "Recent Head Trauma" then 'head-trauma' else null,
    if "Immunocompromised Flag" then 'immunocompromised' else null,
    if "New Or Changed Pain" then 'new-or-changed' else null,
    if "Progressive" then 'progressive' else null,
    if "Positional" then 'positional' else null,
    if "Valsalva Or Exertion" then 'valsalva-exertion' else null,
    if "Cancer Flag" then 'cancer-history' else null,
    if "Vomiting Flag" then 'vomiting' else null,
    if "Severe Pain" then 'severe-pain' else null
  }) F where F is not null
