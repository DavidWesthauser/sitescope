# T-012 Dark mode audit and appearance setting

- Status: todo · Priority: P1 · Estimate: 3 h · Owner: — · Depends on: T-001
- Requirements: M7, G1

## Tasks
- [ ] Find hard-coded colors (`grep -rn "Color.white\|Color.black\|.foregroundStyle(.white)" SiteAR`), replace with semantic/asset colors that have light + dark variants. AR overlays on camera may stay fixed but must stay readable.
- [ ] Add an asset catalog color set (accent/teal, status colors) with dark variants.
- [ ] Settings: Appearance picker System / Light / Dark (`@AppStorage` + `.preferredColorScheme`).
- [ ] Check contrast of status colors (orange "High priority", green completed) in both modes.
- [ ] Layout test captures screens in dark mode.

## Acceptance criteria
- [ ] All screens readable in dark mode (screenshots reviewed).
- [ ] Setting persists across relaunch.
