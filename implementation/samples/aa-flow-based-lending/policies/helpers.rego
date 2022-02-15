package ccr.helpers

# Checks if the specified value is a valid version.
is_valid_version(value) = true {
  pattern := `^1.[0-9]+$`
  regex.match(pattern, value)
}

# Checks if the specified value is a valid GUID.
is_valid_guid(value) = true {
  pattern := `^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$`
  regex.match(pattern, value)
}

# Checks if the specified value is a valid ISO timestamp.
is_timestamp_valid(value) = true {
  pattern := concat("", [`^[0-9]{4}-((0[13578]|1[02])-(0[1-9]|[12][0-9]|3[01])|(0[469]|11)-`,
    `(0[1-9]|[12][0-9]|30)|(02)-(0[1-9]|[12][0-9]))T(0[0-9]|1[0-9]|2[0-3]):(0[0-9]|[1-5][0-9]):`,
    `(0[0-9]|[1-5][0-9])\.[0-9]{3}Z$`])
  regex.match(pattern, value)
} else = true {
  pattern := concat("", [`^[0-9]{4}-((0[13578]|1[02])-(0[1-9]|[12][0-9]|3[01])|(0[469]|11)-`,
    `(0[1-9]|[12][0-9]|30)|(02)-(0[1-9]|[12][0-9]))T(0[0-9]|1[0-9]|2[0-3]):(0[0-9]|[1-5][0-9]):`,
    `(0[0-9]|[1-5][0-9])\.[0-9]{6}$`])
  regex.match(pattern, value)
}

# Verifies a JSON web token for all supported key signing algorithms.
is_signature_verified(value, jwks) = true {
    # Checks for rs256.
    io.jwt.verify_rs256(value, jwks)
} else = true {
    # Checks for rs384.
    io.jwt.verify_rs384(value, jwks)
} else = true {
    # Checks for rs512.
    io.jwt.verify_rs512(value, jwks)
} else = true {
    # Checks for ps256.
    io.jwt.verify_ps256(value, jwks)
} else = true {
    # Checks for ps384.
    io.jwt.verify_ps384(value, jwks)
} else = true {
    # Checks for ps512.
    io.jwt.verify_ps512(value, jwks)
} else = true {
    # Checks for es256.
    io.jwt.verify_es256(value, jwks)
} else = true {
    # Checks for es384.
    io.jwt.verify_es384(value, jwks)
} else = true {
    # Checks for es512.
    io.jwt.verify_es512(value, jwks)
}

# Checks if the specified value is a boolean value.
is_boolean_value(value) = true {
    boolean_set := {"\"True\"","\"False\""}
    count({x | boolean_set[x]; x == value}) == 1
}

# Checks if the specified value is a number in a given range.
is_value_in_range(value, min, max) = true {
  number := to_number(value)
  min <= number; number <= max
}

# Checks if the specified JSON value has the expected number of fields.
is_expected_num_json_fields(json_value, num_fields) = true {
  json.is_valid(json_value)
  count(regex.find_n(`"[\w\d]+":`, json_value, -1)) == num_fields
}
