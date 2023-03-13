package ccr.policy.ocen

import data.ccr.policy.helpers.is_match_found
import data.ccr.policy.helpers.is_valid_guid

# By default, the policy denies the OCEN response.
default is_response_ocen_compliant = false

is_response_ocen_compliant {
  is_valid_loan_application_id(input.loanApplicationId)
  is_valid_loan_application_status(input.loanApplicationStatus)
  is_valid_properties
}

is_valid_loan_application_id(value) = true {
  is_valid_guid(value)
}

is_valid_loan_application_status(value) = true {
  status_set := {"OFFER_ACCEPTED", "PROCESSING", "OFFERED", "GRANTED", "REJECTED"}
  count({x | status_set[x]; is_match_found(x, value)}) == 1
}

# Checks if the loan was offered.
is_valid_properties {
  input.loanApplicationStatus == "OFFERED"
  is_valid_offer(input.offer)
}

# Checks if the loan was rejected.
is_valid_properties {
  input.loanApplicationStatus == "REJECTED"
  is_valid_rejection_details(input.rejectionDetails.reason)
}

is_valid_rejection_details(value) = true {
  reason_set := {"LOW_CREDIT_SCORE", "FRAUD", "DOC_IRREGULARITIES", "OTHERS"}
  count({x | reason_set[x]; is_match_found(x, value)}) == 1
}

is_valid_offer(value) = true {
  is_valid_loan_terms(value.loanTerms)
}

is_valid_loan_terms(value) = true {
  is_valid_requested_amount(value.requestedAmount)
  is_valid_currency(value.currency)
  is_valid_sanctioned_amount(value.sanctionedAmount)
  is_valid_interest_type(value.interestType)
  is_valid_interest_rate(value.interestRate)
  is_valid_total_amount(value.totalAmount)
  is_valid_interest_amount(value.interestAmount)
  is_valid_tenure(value.tenure)
}

is_valid_requested_amount(value) = true {
  pattern := `^[0-9]{1,6}.[0-9]{1,2}$`
  regex.match(pattern, value)
}

is_valid_currency(value) = true {
  currency_set := {"INR"}
  count({x | currency_set[x]; is_match_found(x, value)}) == 1
}

is_valid_sanctioned_amount(value) = true {
  pattern := `^[0-9]{1,6}.[0-9]{1,2}$`
  regex.match(pattern, value)
}

is_valid_interest_type(value) = true {
  interest_type_set := {"FIXED", "FLOATING"}
  count({x | interest_type_set[x]; is_match_found(x, value)}) == 1
}

is_valid_interest_rate(value) = true {
  pattern := `^[0-9]{1,2}.[0-9]{1,2}$`
  regex.match(pattern, value)
}

is_valid_total_amount(value) = true {
  pattern := `^[0-9]{1,6}.[0-9]{1,2}$`
  regex.match(pattern, value)
}

is_valid_interest_amount(value) = true {
  pattern := `^[0-9]{1,4}.[0-9]{1,2}$`
  regex.match(pattern, value)
}

is_valid_tenure(value) = true {
  is_valid_duration(value.duration)
  is_valid_date_unit(value.unit)
}

is_valid_duration(value) = true {
  pattern := `^[0-9]{1,4}$`
  regex.match(pattern, value)
}

is_valid_date_unit(value) = true {
  unit_set := {"MONTH", "DAY", "YEAR"}
  count({x | unit_set[x]; is_match_found(x, value)}) == 1
}
