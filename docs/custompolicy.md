## Custom Policy

 To recap the scenario, we worked on the assumption that the rego policy framework supports (a) the ability to keep track of whether a particular init container was requested to be launched before any other application containers and (b) allows for ability to fail the launch of application containers if a request for init container was not seen. Still as far as we understand the current policy framework (a) does not have a way to know whether the init container was actually launched or not and (b) whether it terminated successfully or not. The requirements for the clean room scenario were:
1. Need verifiable assurance that the init container was started before any other containers
1. Need verifiable assurance that the init container terminated successfully before starting any other containers
1. Ability to fail the launch of the application containers if the init container was not started first or did not terminate successfully

Work-in-progress custom policy being brain-stormed:  

```sh
# gsinha: We are assuming custom policy would have access to the list of containers like below per
# https://msr-gryffindor.visualstudio.com/Taro/_wiki/wikis/GCS%20Policy%20Breakdown/47/framework?anchor=container
containers := [
    {
        "command": ["<command>", "<arg0>", "<arg1>", /*...*/],
        "signals": [/*...*/],
        "env_rules": [
            {
                "pattern": "<pattern>",
                "strategy": "<string|re2>",
                "required": <true|false>
            },
            /*...*/
        ],
        "layers": [
            "<dm-verity hash>",
            /*...*/
        ],
        "mounts": [
            {
                "destination": "<path>",
                "options": ["<option0>", "<option1>", /*...*/],
                "source": "<source regex>",
                "type": "<mount type>"
            },
            /*...*/
        ],
        "allow_elevated": <true|false>,

        # gsinha: New addition. 
        # 1. This looks like useful info to expose anyway
        # 2. Can this help identify which containers are init containers when create_container gets
        # invoked? Or we need to rely on gcsState.containers[] carrying this metadata.
        #  a. This does not have ContainerID field that we could match with gcsState.containers[].
              That looks more like a runtime property though so ContainerID here does not make sense.
        "init": <true|false>,

        "working_dir": "<path>",
        "exec_processes": [
            {
                "command": ["<command>", "<arg0>", "<arg1>", /*...*/],
                "signals": [/*...*/]
            },
            /*...*/
        ],
    }
]

default create_container := {"allowed": false}

create_container := {"metadata": [addStarted, addUnelevated], "allowed": true} {
    not input.allow_elevated
    not data.metadata.started[input.containerID]

    # We're currently brainstorming something like this, where the
    # input object would contain some kind of state object for GCS
    # that it would maintain and expose to policy writers.
    input.gcsState.containers[input.initContainerID].exitCode == 0
    # gsinha: Queries for above:
    # 1. How to identify input.initContainerID for a particular init container given that there can be more than 1 init containers?
    #    Our scenario today has only 1 init container but would be useful to have the flexibility to do this.
    # 2. Would it be possible to say write a rule to express "init container abc should have exited with 0 and init container xyz
    #    should have exited with 3":
    # input.gcsState.containers[input.initContainerID_abc].exitCode == 0
    # input.gcsState.containers[input.initContainerID_xyz].exitCode == 3

    # gsinha: Instead of the above it should be possible for custom policy to simply check that all init containers have exited
    # successfully. Something like below:
    # Assumes we have input.gcsState.containers[].init: <true|false> property available
    # Doubts:
    # 1. We still need to verify that the set below contained the init container of interest. 
    #    So need to do anyways do a containerID based check?
    initContainers := [initContainer | input.gcsState.containers[i].init; initContainer = input.gcsState.containers[i]]
    every initContainer in initContainers {
        initContainer.exitCode == 0
    }

    addStarted := {
        "name": "started",
        "action": "add",
        "key": input.containerID,
        "value": true,
    }

    # as this container has been allowed outside of the framework, we need to
    # track it so we can allow other container-related enforcement points to
    # pass as well
    addUnelevated := {
        "name": "unelevated",
        "action": "add",
        "key": input.containerID,
        "value": true,
    }
}

create_container := result {
    input.allow_elevated
    result := data.framework.create_container
}

# sample container rule
default exec_in_container := {"allowed": false}

exec_in_container := {"allowed": true} {
    data.metadata.unelevated[input.containerID]
}

exec_in_container := result {
    not data.metadata.unelevated[input.containerID]
    result := data.framework.exec_in_container
}
```

## Open questions
### 1. Need metadata to identify which is init container. Something like init.containers[].init whose value is true/false
### 2. Instead of "input.gcsState.containers[input.initContainerID].exitCode == 0" can custom policy also enforce that every init container must have exited with 0 and not just a particular init container id.
### 3. How to identify a particular init container's ID to write a rule such as input.gcsState.containers[input.initContainerID].exitCode == 0?
Do we have to go by containerID or by layer hashes? Is image path an option?
### 4. Purpose of exec_in_container not very clear
1. Can a container in PUT ContainerGroup be launched by going only thru create_container?
1. Or every create_container is followed by exec_in_container and every exec_in_container is preceeded by create_container?
    1. We think we don't need any customization around it.

### 5. How to control container level flags like allow_elevated and stop stdio/debug logging at the container level?
Does public preview tooling only support ARM template as input? If so, are these going to be ARM template inputs at container level or tooling input at a container level? Or we'd have to resort to policy template (JSON) input for tooling?

## Policy authoring steps
1. Run `az confcom` tooling to generate policy that covers the Asima containers (and the ACI fragment).
1. Author a custom policy rego on top of the policy generated above. references to data.framework.xxx in the custom policy map to the tooling generated output.
1. Supply both custom policy rego and the framework rego as ARM input.
    1. **Question**: How to specify 2 rego files as ccePolicy ARM input?
1. Get the Azure subscription whitelisted for custom policy support in ACI.

## CCR Private Preview: Custom Policy support requirements
- At the minimum we need the ability to (a) launch unelevated containers in an ACI container group and (b) author a custom policy that allows for unelevated containers. That way we can have a policy that is static wrt the untrusted containers that we can launch in a sandboxed environment. Not being able to do this will be a private preview blocker.
- Assurances around enforcing init container behavior via custom policy is not a blocker for private preview.
