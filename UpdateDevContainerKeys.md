
# jq and yq examples

- [jq and yq examples](#jq-and-yq-examples)
  - [jq - JSON parser](#jq---json-parser)
    - [Updating a property](#updating-a-property)
    - [Advanced functions](#advanced-functions)
  - [yq - YAML parser](#yq---yaml-parser)
    - [Escape and Unescape JSON strings](#escape-and-unescape-json-strings)


## jq - JSON parser

### Updating a property

- Update existing
  ```bash
  jq '.postCreateCommand = "your-new-command"' devcontainer.json
  ```
- Add postCreateCommand if it doesn't exist, or update if it does:
  ```bash
  jq '.postCreateCommand = "your-new-command"' devcontainer.json
  ```
- More sophisticated version that checks if it exists first
  ```bash
  jq 'if has("postCreateCommand") then .postCreateCommand = "your-new-command" else . + {"postCreateCommand": "your-new-command"} end' devcontainer.json
  ```
- To update in place (modify the file directly)
  ```bash
  jq '.postCreateCommand = "your-new-command"' devcontainer.json > tmp.json && mv tmp.json devcontainer.json
  ```
- Using jq's -i flag for in-place editing (if your jq version supports it)
  ```bash
  jq -i '.postCreateCommand = "your-new-command"' devcontainer.json
  ```

- Examples with specific commands
  - Single command
    ```bash
    jq '.postCreateCommand = "npm install"' devcontainer.json
    ```
  - Multiple commands (array)
    ```bash
    jq '.postCreateCommand = ["npm install", "npm run build"]' devcontainer.json
    ```
  - Complex command with shell:**
    ```bash
    jq '.postCreateCommand = "bash -c \"npm install && npm run setup\""' devcontainer.json
    ```

### Advanced functions
- Merge two json files (deep scanning)
  ```bash
  jq -n '
  def deepmerge(a;b):
    reduce b[] as $item (a;
      reduce ($item | keys_unsorted[]) as $key (.;
        $item[$key] as $val | ($val | type) as $type |
        .[$key] = if ($type == "object") then deepmerge({}; [if .[$key] == null then {} else .[$key] end, $val])
                  elif ($type == "array") then (.[$key] + $val) # Concatenate arrays
                  elif ($type == "null") then .[$key]
                  else $val
                  end
      )
    );
  deepmerge({}; [input, input])' docker-compose.json docker-compose-overrides.json > joined-docker.json
  ```
- Esccaping strings
  
    Here are the key jq commands for escaping and unescaping strings:

    Escaping (Adding JSON escapes):

    - jq -R '@json' - Reads raw input and escapes it as JSON
    - jq '@json' - Escapes a JSON value as a JSON string
    Unescaping (Removing JSON escapes):
    - jq -r '.' - Outputs raw strings without JSON escaping
    - jq -r '.fieldname' - Extracts and unescapes a specific field
      
    Key Options:
    - -R - Read raw strings instead of parsing as JSON
    - -r - Output raw strings instead of JSON texts
    @json - Format strings as JSON (with proper escaping)

    Common Use Cases:
    - Escape shell variables for JSON: echo "$variable" | jq -R '@json'
    - Unescape JSON strings: echo '"escaped string"' | jq -r '.'
    - Process JSON files: jq -r '.field' file.json to get unescaped values
    - Re-escape extracted values: jq -r '.field' file.json | jq -R '@json'

    Example escaping Strings (Adding JSON escapes)
    ```bash
    echo 'Hello "World"\nWith\tTabs and\nNewlines' | jq -R '@json'

    echo 'Path: C:\Users\John\Documents' | jq -R '@json'
    ```

## yq - YAML parser
### Escape and Unescape JSON strings

- Convert yaml to json
  ```bash
  yq -o=json docker-compose-overrides.yaml > docker-compose-overrides.json
  ```
- Convert json to yaml
  ```bash
  yq -p json -o yaml output.json > output.yaml
  ```



