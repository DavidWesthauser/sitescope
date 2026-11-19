# T-026e VoiceOver labels and decorative icons

- Status: todo · Priority: P2 · Estimate: 1.5 h · Owner: — · Depends on: —
- Requirements: G1

## Goal

Give VoiceOver human-readable labels and stop it reading decorative icons, then run a VoiceOver pass on the main screens.

## Tasks

- [ ] Settings gear reads "Gear Shape". Give it the label "Settings".
- [ ] Hide decorative SF Symbols from accessibility (`accessibilityHidden(true)`). Currently read out: "Ar", "Business", "Open Left-Hand Door", "Screenshot", "Light Bulb".
- [ ] VoiceOver pass on Projects, project detail, room and the AR unsupported screen: labels are human-readable and no decorative icon is read out.

## Acceptance criteria

- [ ] Settings gear is announced as "Settings", and a UI test finds it by that label.
- [ ] The five decorative symbols are no longer read out.
- [ ] Accessibility Inspector audit shows no missing-label warnings on the four screens.
