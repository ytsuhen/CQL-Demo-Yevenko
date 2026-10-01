library MoodScreening version '0.1.0'

// Depression and anxiety screening: PHQ-9 and GAD-7 reported by the patient.
// Severity bands follow the published cut points (PHQ-9: 5/10/15/20, GAD-7: 5/10/15).
// Escalation levels are illustrative for the demo, not a clinical recommendation.

using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers
include RulePatterns version '0.1.0' called Patterns

codesystem "LOINC": 'http://loinc.org'
code "PHQ-9 total score": '44261-6' from "LOINC" display 'Patient Health Questionnaire 9 item (PHQ-9) total score [Reported]'
code "PHQ-9 item 9": '44260-8' from "LOINC" display 'Thoughts that you would be better off dead, or of hurting yourself in some way in last 2 weeks [Reported.PHQ]'
code "GAD-7 total score": '70274-6' from "LOINC" display 'Generalized anxiety disorder 7 item (GAD-7) total score [Reported.PHQ]'
code "Not at all": 'LA6568-5' from "LOINC" display 'Not at all'

parameter "Current Level" String

context Patient

// Both questionnaires ask about the last 2 weeks, so an older answer is no longer current
define "Window":
  Interval[Now() - 14 days, Now()]

define "PHQ-9 Answers":
  Patterns."From Patient"([Observation: "PHQ-9 total score"])

define "PHQ-9 Score":
  (Patterns."Latest"("PHQ-9 Answers", "Window").value as FHIR.Quantity).value

define "PHQ-9 Severity":
  if "PHQ-9 Score" is null then null
  else case
    when "PHQ-9 Score" >= 20 then 'Severe'
    when "PHQ-9 Score" >= 15 then 'Moderately severe'
    when "PHQ-9 Score" >= 10 then 'Moderate'
    when "PHQ-9 Score" >= 5 then 'Mild'
    else 'Minimal'
  end

define "Item 9 Answer":
  Patterns."Latest"(Patterns."From Patient"([Observation: "PHQ-9 item 9"]), "Window")

// Item 9 is checked on its own: a low total score does not rule out self-harm thoughts.
// Any answer other than "Not at all" counts; no answer stays unknown (null), never "no".
define "Self-harm Thoughts":
  if "Item 9 Answer" is null then null
  else not ("Item 9 Answer".value as FHIR.CodeableConcept ~ "Not at all")

define "GAD-7 Answers":
  Patterns."From Patient"([Observation: "GAD-7 total score"])

define "GAD-7 Score":
  (Patterns."Latest"("GAD-7 Answers", "Window").value as FHIR.Quantity).value

define "GAD-7 Severity":
  if "GAD-7 Score" is null then null
  else case
    when "GAD-7 Score" >= 15 then 'Severe'
    when "GAD-7 Score" >= 10 then 'Moderate'
    when "GAD-7 Score" >= 5 then 'Mild'
    else 'Minimal'
  end

// "No escalation required" needs both scores; a missing questionnaire leaves the level unknown
define "Proposed Level":
  case
    when "Self-harm Thoughts" then 'ED escalation'
    when "PHQ-9 Score" >= 20 then 'Emergency escalation'
    when "PHQ-9 Score" >= 10 or "GAD-7 Score" >= 10 then 'Urgent escalation'
    when "PHQ-9 Score" is not null and "GAD-7 Score" is not null then 'No escalation required'
    else null
  end

define "New Level":
  Patterns."Monotonic Escalation"("Current Level", "Proposed Level")

define "Ask PHQ-9":
  Patterns."Still Unanswered"("PHQ-9 Answers", "Window")

define "Ask GAD-7":
  Patterns."Still Unanswered"("GAD-7 Answers", "Window")

// What happens next
define "Disposition":
  case "Proposed Level"
    when 'ED escalation' then 'Urgent provider evaluation'
    when 'Emergency escalation' then 'Provider evaluation required'
    when 'Urgent escalation' then 'Provider notification'
    else if "Ask PHQ-9" or "Ask GAD-7" then 'Ask PHQ-9 / GAD-7' else 'Reassure'
  end
