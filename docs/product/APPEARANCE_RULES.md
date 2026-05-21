# Roll Call Appearance Rules

Use these rules when changing Light Mode, Dark Mode, live-screen styling, or sheet presentation.

## Screen Groups

- `Live screens` means `Game Day` and `Clips` only.
- `Setup screens` means every other screen.
- `Lineup sheet` means the `Today’s Lineup` sheet opened from `Game Day`.

## Appearance Matrix

When the device is in Light Mode and `Always Use Dark Live Screens` is off:
- Setup screens render in normal iPhone Light Mode.
- Live screens render content and controls in normal iPhone Light Mode.
- Live screen backgrounds use a gradient from the normal light system grouped background in the upper left to a low-opacity app accent color in the bottom right.
- The lineup sheet renders content, controls, and background in normal iPhone Light Mode.

When the device is in Light Mode and `Always Use Dark Live Screens` is on:
- Setup screens render in normal iPhone Light Mode.
- Live screens render content and controls in normal iPhone Dark Mode.
- Live screen backgrounds use a gradient from the normal dark system grouped background in the upper left to a low-opacity app accent color in the bottom right.
- The lineup sheet renders content, controls, and background in normal iPhone Dark Mode.

When the device is in Dark Mode:
- Setup screens render in normal iPhone Dark Mode.
- Live screens render content and controls in normal iPhone Dark Mode, regardless of the `Always Use Dark Live Screens` setting.
- Live screen backgrounds use a gradient from the normal dark system grouped background in the upper left to a low-opacity app accent color in the bottom right.
- The lineup sheet renders content, controls, and background in normal iPhone Dark Mode.

## Maintenance Notes

- Do not force a global app color scheme to support live screens.
- Apply any forced appearance only to live screens and the lineup sheet presented from `Game Day`.
- Live surfaces should use semantic iOS colors (`label`, `secondaryLabel`, grouped backgrounds, separators) so controls remain normal in both Light Mode and Dark Mode.
- Decorative live backgrounds should be system-background-first; the accent wash should not replace the underlying iOS background color.
