Read the file `data/export.json` in the project directory. It contains the updated DB as a plain JSON object (not wrapped in `const DB = `).

Then update **both** of the following files:

1. **`index.html`** — find the line that starts with `const DB =` (it is a single long line near line 163) and replace the entire line with:
   `const DB = ` + the JSON content (minified, no extra newlines) + `;`

2. **`edit.html`** — find the line that starts with `let DB =` (it is a single long line near line 154) and replace the entire line with:
   `let DB = ` + the JSON content (minified, no extra newlines) + `;`

Important:
- Use `Read` to load `data/export.json`, then parse it as JSON.
- The replacement must be a **single line** with no line breaks inside the JSON — do not pretty-print it inline.
- Do not change anything else in either file.
- After updating, confirm how many services are in the DB and which service was most recently changed (compare the valid_from dates).
