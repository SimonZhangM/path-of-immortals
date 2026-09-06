# Path of Immortals

Godot 4.7.2 · GDScript 2.x · Mobile renderer · Windows-first 2D cultivation/build game.

- At the start of every task, read `PROJECT_PROGRESS.md` for current scope, completed work, validation, limitations and next steps. Check actual code and Git state before relying on its status.
- Before implementing a new user request, think through missing gameplay rules and material ambiguities. If any exist, ask and resolve them before editing; the user explicitly requested this workflow. Do not re-ask already confirmed rules.
- Before finishing or handing off a task, update `PROJECT_PROGRESS.md` with the date, changes, validation performed (or not run), unfinished work and next steps. Keep recommendations distinct from user-approved scope; do not leave essential handoff information only in chat.
- Use Godot 4 APIs. Do not add C#, Node.js, Electron or unnecessary dependencies.
- Keep Data → Registry → Simulation → Game State → UI boundaries clear.
- Gameplay simulation must run without a scene tree, UI, animations or wall-clock queries.
- UI reads authoritative state and sends commands; never infer gameplay state from controls.
- Load ordinary content from JSON and resolve it through stable, namespaced IDs. Never rename published IDs or create one script per ordinary item.
- Use reusable effects and scheduled events; do not poll every item every frame.
- Speed scales simulation time only. Never change Engine.time_scale for battle speed.
- Use Containers, anchors and size flags for layouts. Keep presentation independent of simulation.
- Keep event ordering deterministic, including simultaneous events. Reject invalid content before starting simulation.
- Current authorized scope is V0.4: formations for 1/2/3 members, default allied front hero on the right and two rear companions on the left; a single centered enemy wild dog; mirrored team UI, fixed hero-sized backpack and smaller companion bags, and two-sided combat. Swords deal 10 and claws deal 5 every 3 seconds, each activation costs the attacker 5 stamina. Front living targets first, top before bottom; fallen or exhausted owners stop attacking. Victory/defeat on team elimination, draw when neither team can attack. Inventory/formation editing is preparation-only, including direct editing of companion bags; battle and pause both lock edits. Clicking characters never enlarges backpacks. Keep 1920x1080, centered timer, speed controls to its right, Space start/pause/resume and F1/F2/F3 for 0.5/1/2x. Armor defense and unrelated progression remain out of scope.
- Reserve future save data for stable IDs and instance/progress state. Do not implement full saves, MOD scripting, Lua, PCK loading or Steam integration yet.
- Document major architecture changes before implementation. Prefer simple solutions suitable for a solo developer.
- Run the headless tests and a project startup check before completing relevant changes. See README.md for commands.
- Do not commit Godot caches, local logs, temporary files or exported binaries. Do not invent a Git author identity.
