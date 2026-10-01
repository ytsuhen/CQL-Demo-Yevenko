library SymptomTriage version '1.0.0'

using FHIR version '4.0.1'
include FHIRHelpers version '4.0.1' called FHIRHelpers
include RulePatterns version '0.1.0' called Patterns

codesystem "LOINC": 'http://loinc.org'
code "Pain severity 0-10": '72514-3' from "LOINC" display 'Pain severity - 0-10 verbal numeric rating [Score] - Reported'
valueset "Red-flag symptoms": 'urn:example:cql-demo:valueset:red-flag-symptoms'

parameter "Last Run" DateTime
parameter "Current Level" String

context Patient

define "Window":
  Patterns."Conversation Window"("Last Run", 12 hours)

define "Pain Reports":
  Patterns."From Patient"([Observation: "Pain severity 0-10"])

define "Pain Evidence":
  Patterns."Latest"("Pain Reports", "Window")

define "Pain Now":
  ("Pain Evidence".value as FHIR.Quantity).value

define "Red Flag Reported":
  exists Patterns."In Window"(Patterns."From Patient"([Observation: "Red-flag symptoms"]), "Window")

define "Proposed Level":
  case
    when "Red Flag Reported" then 'ED escalation'
    when "Pain Now" >= 8 then 'Emergency escalation'
    when "Pain Now" >= 4 then 'Urgent escalation'
    when "Pain Now" is not null then 'No escalation required'
    else null
  end

define "New Level":
  Patterns."Monotonic Escalation"("Current Level", "Proposed Level")

define "Ask Pain Score":
  Patterns."Still Unanswered"("Pain Reports", "Window")

// What happens next. "New Level" decides whether a new alert goes out; this says what the patient needs.
define "Disposition":
  case "Proposed Level"
    when 'ED escalation' then 'Emergency Department evaluation'
    when 'Emergency escalation' then 'Provider evaluation required'
    when 'Urgent escalation' then 'Provider notification'
    else if "Ask Pain Score" then 'Ask pain score' else 'Reassure'
  end
