# Project Chat Files Workbench Plan

## Goal
- Rebuild the `project chat -> files/code` experience into a lightweight workbench with VS Code style interaction.
- Keep the current `ProjectChatCodeTab`, `FilePreview`, storage APIs, project chat flow, and macOS import entrypoints.
- Prioritize minimal code churn, high performance, strong desktop interaction, and higher information density on macOS only.
- Support a future hybrid workspace model:
  - local folder attached on macOS
  - cloud workspace sync
  - GitHub sync

## Constraints
- Do not regress iOS / Android behavior.
- macOS specific density and local workspace behavior must stay isolated behind desktop/macOS checks.
- Do not attempt a full IDE clone. Skip breakpoints, terminal, debugger, and heavy LSP features.
- Every small milestone must be verified before being checked off.

## Product Direction
- Single click in tree: preview editor.
- Double click or edit: pinned editor tab.
- Multiple open editors with per-file dirty state.
- Save semantics should feel local-first, then sync outward.
- Explorer, tabs, editor, and sync state must read like a workbench, not a card-based file browser.
- macOS gets tighter row heights, denser chrome, and flatter panel styling.

## Architecture Direction

### Keep
- `lib/widgets/chat/project_chat/code_tab/project_chat_code_tab.dart`
- `lib/widgets/chat/file_preview.dart`
- `lib/widgets/chat/project_chat/code_tab/code_tab_code_block.dart`
- `lib/services/macos_folder_import_service.dart`
- Existing storage APIs in `lib/services/d1vai_service.dart`

### Add
- `CodeWorkbenchController`
- editor tab model with preview/pinned semantics
- per-file edit buffers and dirty tracking
- macOS density tokens for tree rows, tabs, and toolbar
- local workspace bridge in a later phase

### Avoid for now
- full editor replacement
- background real-time bidirectional sync engine
- advanced git UI
- breakpoint/debugger functionality

## Milestones

### M1: Workbench foundation inside current code tab
Scope: finish now.

#### M1 checklist
- [x] M1.1 Rewrite `ProjectChatCodeTab` state from single-file mode to workbench state.
- [x] M1.2 Add preview tab + pinned tab behavior.
- [x] M1.3 Add multiple open editors with independent buffers and dirty dots.
- [x] M1.4 Upgrade desktop viewer area to a tabbed editor workbench.
- [x] M1.5 Tighten macOS-only density for tree rows, tabs, and toolbar.
- [x] M1.6 Preserve save / unsaved-confirm flows across multiple editors.
- [x] M1.7 Run targeted validation for M1 and keep code passing.

#### M1 implementation notes
- Introduce a controller/model layer instead of more booleans on the widget state.
- Keep existing file fetch and save endpoints.
- Reuse `FilePreview` and `CodeTabCodeBlock` where possible.
- Do not change mobile navigation model yet beyond compatibility fixes.
- Keep AI actions available on the active file.

### M2: macOS local folder attach and open
Scope: detail after M1 is complete.

#### M2 draft TODO
- [ ] M2.1 Add a macOS-only workbench open mode switch:
  - `Open local folder`
  - `Import to cloud project`
  - `Attach local folder to current project`
- [ ] M2.2 Accept drag-and-drop into the app window:
  - app shell detects dropped file/folder path
  - if no active project, reuse import flow
  - if inside `project chat/code`, show attach vs import chooser
- [ ] M2.3 Add Dock/open-document handling:
  - receive folder path from macOS open-file event
  - route directly into workbench local-open flow
  - preserve existing navigation semantics
- [ ] M2.4 Build `LocalWorkspaceService`:
  - `openFolder(path)`
  - `readTree(path)`
  - `readFile(path)`
  - `writeFile(path, content)`
  - root metadata such as folder name and writable state
- [ ] M2.5 Extend workbench source model:
  - `cloudOnly`
  - `localAttached`
  - `hybrid`
  - active local root path
  - per-file source and sync status
- [ ] M2.6 Add local workspace chrome to the code workbench:
  - local root breadcrumb
  - local/cloud/github sync badges
  - quick actions for `Reveal in Finder` and `Sync Now`
- [ ] M2.7 Keep mobile unchanged:
  - no local folder attach on iOS / Android
  - no density changes outside macOS
  - current mobile file page flow stays intact

### M3: Hybrid sync model
- [ ] local save first
- [ ] debounced cloud sync
- [ ] explicit GitHub sync state
- [ ] per-file sync indicators
- [ ] conflict/error presentation

### M4: Further interaction polish
- [ ] quick open
- [ ] right click file actions
- [ ] keyboard navigation
- [ ] compare/proposed changes flow
- [ ] diagnostics/problems surface

## Verification Rule
- After each completed M1 item:
  1. run targeted `flutter analyze` or equivalent validation
  2. update this checklist
  3. continue immediately to the next item

## M1 result
- Added `CodeWorkbenchController` with multi-editor state, preview tab tracking, pinned tab promotion, per-file buffers, dirty state, and save handling.
- Upgraded desktop code tab into a tabbed workbench while keeping the mobile file viewer flow.
- Added macOS-only compact density for explorer rows, tab strip, toolbar spacing, and editor chrome.
- Preserved existing cloud file fetch/save API usage and AI entrypoint on the active file.

## M1 validation
- `flutter analyze lib/widgets/chat/project_chat/code_tab/project_chat_code_tab.dart lib/widgets/chat/project_chat/code_tab/code_workbench_controller.dart lib/widgets/chat/project_chat/code_tab/code_tab_editor_tabs.dart lib/widgets/chat/project_chat/code_tab/code_tab_tree_panel.dart lib/widgets/chat/project_chat/code_tab/code_tab_file_viewer.dart lib/widgets/chat/project_chat/code_tab/code_tab_editor.dart lib/l10n/generated_localizations.dart test/widget_test.dart` ✅
- `flutter test` ✅

## Current Focus
- Active milestone: `M2`
- Immediate next task: `M2.1 Add a macOS-only workbench open mode switch`
