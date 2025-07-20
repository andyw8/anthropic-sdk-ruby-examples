---
description: Convert
tools: "WebFetch(domain:cc.sj-cdn.net)",
---

## Your task

Steps:
- Download the Python Jupyter notebook at $ARGUMENTS to a temporary file.
- Convert it to Ruby. Ensure ALL cells from the notebook are converted.
- Save it as single Ruby file (prompt the user for the output path)
- Commit this as "Initial conversion to Ruby"
- Use `bundle exec ruby -wc` to check if the Ruby code is valid.
- If there are syntax errors, stop and ask the user what to do.
- Run `standardrb --fix` to fix any style issues.
- Commit again if anything was fixed.
- Try run the Ruby code
- Clean up the temporary file.

*Notes*:
- In places where the Python code uses string literals comparisions, the Ruby equivalent is normally a symbol, e.g. for `response.stop_reason`.
- Any local variables at the top level may need to be converted to constants.
- Use `require "dotenv/load"` to load the environment variables.
- Don't put any `#!/usr/bin/env ruby` at the top of the file.
