library RulePatterns version '0.1.0'

using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers

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
