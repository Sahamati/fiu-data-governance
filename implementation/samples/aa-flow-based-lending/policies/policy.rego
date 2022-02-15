package ccr.policy

import data.ccr.helpers.is_valid_version
import data.ccr.helpers.is_valid_guid
import data.ccr.helpers.is_timestamp_valid
import data.ccr.helpers.is_signature_verified
import data.ccr.helpers.is_value_in_range
import data.ccr.helpers.is_expected_num_json_fields 

# By default, the policy denies all requests.
default allow_incoming_request = false
default allow_incoming_response = false
default allow_outgoing_request = false
default allow_outgoing_response = false

# Rule that checks if an incoming request is allowed.
allow_incoming_request {
  print("Validating compliance of incoming request.")
  # The policy allows an incoming request if all consent checks pass.
  count(deny_incoming_request) == 0
}

# Rule that checks if an incoming response is allowed.
allow_incoming_response {
  print("Validating compliance of incoming response.")
  true
}

# Rule that checks if an outgoing request is allowed.
allow_outgoing_request {
  print("Validating compliance of outgoing request.")
  true
}

# Rule that checks if an outgoing response is allowed.
allow_outgoing_response {
  print("Validating compliance of outgoing response.")
  # The policy allows an outgoing response if all consent checks pass.
  count(deny_outgoing_response) == 0
}

deny_incoming_request["Failed policy check: invalid consent signature"] {
  not is_consent_signature_valid
}

deny_incoming_request["Failed policy check: consent is not active"] {
  not is_consent_active
}

deny_outgoing_response["Failed egress policy check: response is not compliant"] {
  not is_response_compliant
}

# Checks if the consent signature is valid.
is_consent_signature_valid = true {
  trace("Verifying consent signature.")
  # Decode consent signature.          
  [header, consent_detail, _] := io.jwt.decode(input.Consent.consentArtefact.signedConsent)      
  # Find index of aa_info for data_provider specified in payload of the signed consent.
  input.entities[k].entityinfo.id == consent_detail.DataProvider.id
  # Extract corresponding certs.
  certificate := input.entities[k].entityinfo.certificate
  # Create jwks from certs.
  jwks = json.marshal({ "keys": [certificate]})
  # Verify signature.
  is_signature_verified(input.Consent.consentArtefact.signedConsent, jwks)
}

# Checks consent start and expiry dates against current time.
is_consent_active = true {
  trace("Checking if consent is active for this period.")
  # Extract the consent detail from the signed consent.
  [header, consent_detail, _] := io.jwt.decode(input.Consent.consentArtefact.signedConsent)
  # Parse dates from ISO to ns.
  consent_start := time.parse_rfc3339_ns(consent_detail.consentStart)
  consent_expiry := time.parse_rfc3339_ns(consent_detail.consentExpiry)
  # Get current time in ns.
  current_time := time.now_ns()
  # Compare current time with consent start and expiry.
  is_value_in_range(current_time, consent_start, consent_expiry)
}

# Checks if the response is compliant.
is_response_compliant = true {
  trace("Checking if response is compliant.")
  # All checks must pass for the response to be compliant.
  input_json := json.marshal(input)
  is_expected_num_json_fields(input_json, 4)
  is_valid_version(input.ver)
  is_valid_guid(input.txnid)
  is_timestamp_valid(input.timestamp)
  is_value_in_range(input.score, 1, 100)
}
