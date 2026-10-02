library RulePatterns version '0.1.0'

using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers

codesystem "LOINC": 'http://loinc.org'
code "Yes": 'LA33-6' from "LOINC" display 'Yes'

// Building blocks every clinical rule reuses.

// Conversation window: since the last run, but at least `lookback` back
// (no previous run: the last `lookback` hours)
define function "Conversation Window"(lastRun DateTime, lookback System.Quantity):
  Interval[Min({ Coalesce(lastRun, Now()), Now() - lookback }), Now()]

// Facts from trusted sources only: the source is a tag in meta.tag
define function "From Sources"(obs List<Observation>, sources List<System.String>):
  obs O where exists (O.meta.tag T where T.code.value in sources)

define function "From Patient"(obs List<Observation>):
  "From Sources"(obs, { 'Patient', 'RPM' })

// Background facts (pregnancy, immunosuppression, cancer history) may also be entered by a clinician
define function "From Record"(obs List<Observation>):
  "From Sources"(obs, { 'Patient', 'RPM', 'MANUAL' })

// A question counts as answered only when its Observation has a value: an empty Observation is no answer
define function "Answered"(obs List<Observation>):
  obs O where O.value is not null

// A yes/no question raises a flag only on Yes: "No" is a fact, not a flag
define function "Answered Yes"(obs List<Observation>):
  obs O where (O.value as FHIR.CodeableConcept) ~ "Yes"

// Facts whose value is a date no older than `lookback`, e.g. a head injury in the last 90 days.
// The fact itself is recorded when the patient answers; the date of the event is its value.
define function "Dated Within"(obs List<Observation>, lookback System.Quantity):
  obs O where date from (O.value as FHIR.dateTime).value >= Today() - lookback

// Facts whose clinical time falls in the window
define function "In Window"(obs List<Observation>, w Interval<DateTime>):
  obs O where (O.effective as FHIR.dateTime) during w

// The latest fact in the window
define function "Latest"(obs List<Observation>, w Interval<DateTime>):
  Last(("In Window"(obs, w)) O sort by (effective as FHIR.dateTime).value)

// Keep asking until the patient answers
define function "Still Unanswered"(obs List<Observation>, w Interval<DateTime>):
  not exists "In Window"(obs, w)

// Escalation levels, lowest to highest. "No escalation required" and an unknown level never raise an alert.
define function "Rank"(level System.String):
  case level
    when 'ED escalation' then 3
    when 'Emergency escalation' then 2
    when 'Urgent escalation' then 1
    else 0
  end

// Escalation only goes up within an episode: a new alert only for a higher level than the current one
define function "Monotonic Escalation"(current System.String, proposed System.String):
  if "Rank"(proposed) > "Rank"(current) then proposed else null
