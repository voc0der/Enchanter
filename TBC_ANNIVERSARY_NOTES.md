## TBC Anniversary Fork Notes

Working branch: `tbc-anniversary-base`

What was promoted into the repo root:
- `20505` TOC target
- TBC-oriented recipe/tag data
- Anniversary-style settings panel builder
- Generic `LF Enchanter` whisper support
- Invite/whisper delay settings
- Session gold summary command

Important cleanup already applied:
- Added API fallbacks for `C_AddOns`, `C_PartyInfo`, `C_Timer`, and profession scan APIs
- Removed the stray `GroupBulletinBoardDB` dependency from the imported options code
- Added legacy options fallbacks when modern `Settings` APIs are unavailable
- Rebuilds compiled match patterns after scans and option changes
- Flattened the addon so the runtime files now live at repo root for cleaner packaging and release automation

Still needs real client validation:
- `/ec scan` on the live TBC Anniversary client
- `/ec config` opening the settings page
- Invite/whisper timing behavior
- Recipe link generation on whichever profession API path the client exposes

Suggested next steps:
1. Test scan + config in-game and capture any Lua errors.
2. Verify whether the live client prefers the craft API path or the trade-skill API path.
3. Trim or expand tags based on real trade chat misses/false positives.
