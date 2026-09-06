# Path of Immortals

Godot 4.7.2 · GDScript 2.x · Mobile renderer · Windows-first 2D cultivation/build game.

- At the start of every task, read `PROJECT_PROGRESS.md` for current scope, completed work, validation, limitations and next steps. Check actual code and Git state before relying on its status.
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
- V0.1 implements only one weapon, one dummy, damage, pause, restart and 1/2/4/8x. Do not start phase two without the user's request.
- Reserve future save data for stable IDs and instance/progress state. Do not implement full saves, MOD scripting, Lua, PCK loading or Steam integration yet.
- Document major architecture changes before implementation. Prefer simple solutions suitable for a solo developer.
- Run the headless tests and a project startup check before completing relevant changes. See README.md for commands.
- Do not commit Godot caches, local logs, temporary files or exported binaries. Do not invent a Git author identity.
