package ccr.policy

import future.keywords

is_analyze_statements = result {
    get_method == "POST"
    get_path == "/AnalyzeStatements"
    result := {
        "allowed": true,
        "context": create_context
    }
}

on_analyze_statements = result {
    input.context.method == "POST"
    input.context.path == "/AnalyzeStatements"
    result := { "allowed": true }
}

on_analyze_statements_response = result {
    input.context.method == "POST"
    input.context.path == "/AnalyzeStatements"
    result := { "allowed": true }
}