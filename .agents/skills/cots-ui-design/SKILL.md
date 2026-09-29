---
name: cots-ui-design
description: Implement or review Flutter UI/UX changes in COTS Monitor using its existing colors, typography, responsive layouts, navigation, and reusable components. Use for project screens and interactions, not unrelated app redesigns.
---

# COTS Monitor UI design

All paths are relative to the project root. Inspect the affected screen, its shell, and nearby components before editing. Keep changes minimal and focused on the requested user outcome.

## Existing visual language

- The app uses Material 3 in `lib/main.dart`. Preserve the marine palette and the distinct auth, user, landing, and admin contexts.
- Reuse `lib/core/cots_colors.dart` for shared teal, navy, semantic colors, borders, and soft card shadows; use `lib/core/user_shell_theme.dart` where the user screen already uses its navy/teal palette.
- Auth colors, sizes, and radii live in `lib/features/auth/widgets/auth_layout.dart` as `AuthTokens`. Landing colors live in `lib/features/landing/landing_theme.dart`.
- Admin colors, Inter typography, and date/refresh styles live in `lib/features/admin/theme/admin_theme.dart`. Reuse `AdminColors` and `AdminDateTimeTokens`; do not copy auth gradients into admin controls.
- Prefer existing tokens over new hex values. Preserve semantic meanings for warnings, errors, success, and map severity; do not recolor statuses merely for decoration.

## Spacing and typography

- Match the nearest comparable screen's padding, gaps, alignment, radii, and text hierarchy. There is no single universal spacing scale to impose across this project.
- Use `AdminBreakpoints.pagePadding` for admin page spacing. Auth scaffolds already provide mobile margins and constrained form cards; avoid adding a second layer of page padding.
- Reuse the active theme's text styles and local shared tokens. Keep headings, body text, field labels, captions, and metadata visually distinct without introducing new fonts.
- Let long names, locations, validation messages, and larger text wrap. Avoid shrinking text or forcing fixed heights to conceal overflow; reserve ellipsis for summaries whose full value remains available.
- Use whitespace to group related content. Avoid excessive gaps, dense rows, nested cards, and repeated headings.

## Mobile-first responsive layouts

- Make the primary task usable on a narrow phone first, then enhance wider layouts. Use available constraints through `LayoutBuilder`, flexible children, and wrapping controls rather than device-name checks or fixed desktop widths.
- Respect safe areas, keyboard insets, and bottom navigation. Keep forms and dialog content scrollable when needed, with primary actions reachable.
- Auth uses `AuthResponsiveScaffold` and `AuthBreakpoints`: tablet starts at 768, desktop at 1200, page maximum width is 1100, and form-card maximum width is 480 logical pixels.
- Admin uses `lib/features/admin/layout/admin_breakpoints.dart`: mobile below 768, desktop from 1024, and wide content from 1100. Reuse existing drawer/sidebar and responsive chrome instead of inventing parallel breakpoints.
- Stack cards and form groups when space is limited. Preserve readable data and accessible actions; use existing table scrolling where appropriate instead of squeezing all columns onto a phone.
- Treat these as context-specific conventions, not breakpoints to apply indiscriminately to every user screen.

## Reusable components and interactions

Search existing widgets and callers before creating a component. Extend a compatible widget where useful; extract a new shared widget only for a concrete reuse need.

- **Buttons:** Reuse `CotsGradientPrimaryButton` for auth and existing Material/admin button styles elsewhere. Use clear action labels and a clear primary action per task. Show loading, prevent duplicate submission, and retain focus and pressed feedback.
- **Cards and tables:** Reuse `AdminStatCard` and the `AdminDataTable*` helpers in `lib/features/admin/widgets/`. Match local card padding, borders, and shadows; make interactivity apparent.
- **Forms:** Reuse `CotsAuthTextField`, `CotsAuthPasswordField`, `CotsAuthDropdown`, and auth card/scaffold widgets under `lib/features/auth/widgets/` for matching auth flows. Preserve visible labels, validation, input types, autofill, next/done actions, and entered values after errors.
- **Dialogs:** Inspect `admin_record_details_dialogs.dart`, `admin_report_modals.dart`, and existing screen bottom sheets before adding an overlay. Keep titles and actions clear, content bounded and scrollable, dismissal predictable, and controls reachable with the keyboard open. Verify inherited desktop dimensions on phones.
- **Navigation:** Reuse `UserBottomNavBar` in `lib/features/user/user_bottom_nav.dart`, `AppBackIconButton`, and the admin back-button wrapper. Preserve selected destinations, back behavior, scan entry, and role-aware auth/admin/expert shells; do not duplicate navigation bars.
- **Images and maps:** Reuse `SubmittedScanImage`, `CotsDetectionImageOverlay`, and `MarineSectorMapLabel` in `lib/widgets/`. Preserve image aspect ratio and box alignment; use existing marine-sector colors and readable legends.

## Accessibility and readable interfaces

- Preserve system text scaling and test enlarged text. Use readable contrast for text, icons, borders, and focus states; existing colors still need checking against their actual background.
- Pair status colors with text or icons. Detection acceptance, expert review, and retake labels must continue to use the existing confidence policy rather than new UI-only interpretations.
- Give icon-only actions tooltips and accessible names. Use Material controls and meaningful semantics, with logical keyboard focus and screen-reader reading order.
- Keep touch targets generous; aim for at least 48 logical pixels for new mobile controls. Do not shrink shared controls or silently copy cramped dimensions. Fix accessibility limitations in touched components without expanding into an unrelated redesign.
- Do not rely on hover, motion, or map colors alone to convey essential information. Keep animations restrained and respect reduced-motion preferences when adding motion.
- Provide concise loading, empty, failure, and retry states. Distinguish unavailable data from zero detections; retain useful context and user input.

## Minimal, clean changes

- Preserve the existing interface unless the request specifically calls for a redesign. Solve the identified layout or interaction problem with the smallest coherent change.
- Avoid decorative controls, duplicate actions, extra dashboards, unnecessary animations, speculative settings, placeholder content, and new UI packages without a concrete need.
- Do not change business rules, persistence, routes, global themes, or unrelated screens as a side effect of styling. Check all affected callers before changing shared components.
- Keep existing user edits intact. Add only necessary files; avoid mass formatting and broad component extraction for a local fix.

## Verify the result

- Inspect changed screens at narrow phone and wider sizes, plus relevant breakpoint boundaries. Check long/empty content, keyboard visibility, enlarged text, scrolling, and loading/error/disabled states.
- Exercise affected taps, form validation, dialog dismissal, selected navigation, and back behavior. Check that image overlays and map controls remain usable when touched.
- Format changed Dart files, run `flutter analyze`, and run relevant tests. Add focused widget tests for meaningful changed behavior when warranted; do not add tests solely to mirror cosmetic constants.
- Review the diff for unrelated edits and report checks actually performed and any limitations. For a skill-only change, validate the skill file and references; an application build is unnecessary.
