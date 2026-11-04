// npm shows the README and LICENSE inside the published package. One copy of each lives in
// sdks/react; this puts them in the package being packed (both copies are git-ignored).
import { copyFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
for (const file of ["README.md", "LICENSE"]) {
  copyFileSync(join(here, file === "LICENSE" ? "../LICENSE" : file), join(process.cwd(), file));
}
