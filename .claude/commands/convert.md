---
description: Convert
tools: "WebFetch(domain:cc.sj-cdn.net)","Bash(curl:*")",Write(),Update()
---

## Your task

**Steps**:
- Download the Python Jupyter notebook at $ARGUMENTS to a temporary file.
- Convert it to Ruby. Ensure ALL cells from the notebook are converted.
- Retain the comments from the Jupyter notebook but don't add new ones
- Save it as single Ruby file (prompt the user for the output path)
- Commit this as "Initial conversion to Ruby"
- Use `bundle exec ruby -wc` to check if the Ruby code is valid.
- If there are syntax errors, stop and ask the user what to do.
- Run `standardrb --fix` to fix any style issues.
- Commit again if anything was fixed.
- Update the README.md to link to the newly added Ruby file.
- Commit the README changes
- Try run the Ruby code
- Clean up the temporary file.
- If any of the code appears to unused (e.g. methods that are never called) then let the user know.

**Notes**:
- In places where the Python code uses string literal comparisions, the Ruby equivalent is normally a symbol, e.g. for `response.stop_reason`.
- Any local variables at the top level may need to be converted to constants.
- Use `require "dotenv/load"` to load the environment variables.
- Don't put any `#!/usr/bin/env ruby` at the top of the file.
- In places where the Python does a type check such as `isinstance(Message)`, the Ruby code will need to use the fully qualified class name, e.g. `is_a?(Anthropic::Message)`-
- For tool signatures within the converted code, prefer keyword arguments over positional arguments.
- Don't use `respond_to?`, use `is_a?` checks instead.
- For the VoyageAI client, name it `VOYAGEAI_CLIENT`, not `CLIENT`.
