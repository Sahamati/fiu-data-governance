package ccr.policy

import future.keywords

set_key(id, value) := key if {
    serialized_value := json.marshal(value)
    request := {
        "id": id,
        "value": serialized_value
    }
    endpoint := sprintf("http://%s:%d/item", [data.host, data.local.keyprovider_sidecar.port])
    response := http.send({
        "method": "post",
        "url": endpoint,
        "raise_error": false,
        "headers": { "Content-Type": "application/json" },
        "body": request})
    print(sprintf("key provider POST /item response: %v", [response]))
    response.status_code == 200
    key := response.body.id
}

get_key(id) := value if {
    endpoint := sprintf("http://%s:%d/items/%s", [data.host, data.local.keyprovider_sidecar.port, id])
    response := http.send({
        "method": "get",
        "url": endpoint,
        "raise_error": false,
        "headers": { "Content-Type": "application/json" }})
    print(sprintf("key provider GET /items/%s response: %v", [id, response]))
    response.status_code == 200
    value := json.unmarshal(response.body.value)
}
