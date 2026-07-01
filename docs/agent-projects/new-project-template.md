# New Project Template Profile

Use this as a starting point for future projects. Add a project-specific profile only when the project has durable quirks, protected core workflows, release/user/data risk, recurring maintenance needs, or exceptions worth documenting. For tiny utilities, experiments, throwaway prototypes, personal toys, or one-off scripts, prefer no project profile unless John asks.

## Defaults

- Bundle identifiers default to `com.sidelarklabs.<appname>`.
- MIT is the assumed default license unless John changes it for a project; project-specific license decisions must be respected.
- READMEs should be minimal: briefly describe the app/tool and point readers to `https://sidelarklabs.com`.
- About screens, credits, distribution notes, and licensing surfaces should credit `Sidelark Labs ; John Kenneth Fisher` and link to the public GitHub page and the Sidelark Labs page if they exist.
- Verification: scaled to risk; cheapest meaningful check first; batch heavyweight checks.

## Suggested profile contents

Keep profiles tiny:

- project identity,
- known exceptions,
- protected core workflows,
- project-specific docs to route to,
- project-specific excluded/generated paths,
- project-specific verification quirks.

If a rule could reasonably apply to more than one project, put it in a universal conditional rule file instead.
