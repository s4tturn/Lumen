# Apple Platform Development

For every Apple-platform development task, use the installed Agent Skills and MCP capabilities deliberately rather than relying solely on general model knowledge.

Use the smallest set of skills that materially improves the task, but do not omit a relevant specialist skill when it provides important guidance. Prefer authoritative, directly relevant Apple guidance first, then use additional specialist skills as implementation or review layers.

Apple's official Xcode/Apple skills and current Apple documentation are authoritative. Community skills provide additional expertise and must never override current Apple documentation, SDK behavior, or platform conventions.

## Primary Apple Research Source: Sosumi

Rely heavily on the installed `sosumi` skill for Apple-platform research and verification.

Use Sosumi whenever the task involves:

* Apple APIs or frameworks.
* Determining whether an API exists or is current.
* Learning how an Apple API is intended to be used.
* Choosing between Apple APIs or implementation approaches.
* SwiftUI, UIKit, AppKit, App Intents, or other Apple frameworks.
* Human Interface Guidelines and Apple design conventions.
* Liquid Glass and modern Apple UI patterns.
* Animation, transitions, interaction, and motion behavior.
* Accessibility and platform-specific behavior.
* Deployment-target or availability questions.
* WWDC guidance, implementation patterns, or Apple's recommended approaches.
* Resolving uncertainty about an Apple API, behavior, design decision, or best practice.

Sosumi provides access to Apple documentation, Human Interface Guidelines, and WWDC transcripts. Use that information as a primary source when researching APIs and making implementation or design decisions.

Do not invent, guess, or rely on stale model knowledge when current Apple documentation can verify the answer.

When there is a conflict between general model knowledge and current Apple documentation retrieved through Sosumi, follow the current Apple documentation.

## Installed Skills

The following skills are available in this project:

* `swiftui-whats-new-27` — current SwiftUI APIs and changes in the latest SDK.
* `swiftui-specialist` — specialized SwiftUI implementation guidance.
* `swiftui-expert-skill` — advanced SwiftUI architecture, performance, correctness, and best practices.
* `swiftui-pro` — SwiftUI review, modernization, accessibility, performance, and platform-quality guidance.
* `apple-design` — Apple Human Interface Guidelines and platform design conventions.
* `apple-motion-feel` — Apple-like animation, interaction, spring, and motion behavior.
* `liquid-glass` — Liquid Glass implementation and platform guidance.
* `liquid-glass-motion` — Liquid Glass transitions, effects, and motion behavior.
* `app-intents-specialist` — App Intents implementation and architecture.
* `app-intents-whats-new-27` — current App Intents APIs and changes.
* `uikit-app-modernization` — modern UIKit APIs and modernization.
* `building-document-based-swiftui-applications` — document-based SwiftUI application architecture.
* `modernize-tests` — modern Swift/Xcode testing practices.
* `adopt-c-bounds-safety` — C bounds-safety modernization.
* `audit-xcode-security-settings` — Xcode security and project configuration auditing.
* `device-interaction` — Apple device interaction, installation, execution, and device workflows.

### Skill Selection

Before implementing, determine which installed skills materially apply to the task.

For example:

* SwiftUI UI → `swiftui-specialist`, `swiftui-expert-skill`, `swiftui-pro`, and relevant current SwiftUI guidance.
* New SwiftUI APIs → `swiftui-whats-new-27` + Sosumi.
* Apple visual design → `apple-design` + Sosumi.
* Motion/animation → `apple-motion-feel` + Sosumi.
* Liquid Glass → `liquid-glass` + `liquid-glass-motion` + Sosumi.
* App Intents → `app-intents-specialist` + `app-intents-whats-new-27` + Sosumi.
* UIKit → `uikit-app-modernization` + Sosumi.
* Document-based apps → `building-document-based-swiftui-applications` + relevant SwiftUI skills.
* Testing → `modernize-tests` + Sosumi where current API behavior needs verification.
* Security → `audit-xcode-security-settings`.
* C code or C interoperability → `adopt-c-bounds-safety`.
* Device/build/install interaction → `device-interaction` and the available Xcode MCP tools.

Do not mechanically load or apply every skill to every task. Use the relevant skills as focused expertise.

## Before Implementing

Before writing code:

1. Identify the platform: iOS, iPadOS, macOS, Mac Catalyst, watchOS, tvOS, or visionOS.
2. Identify the deployment target and SDK.
3. Determine the relevant Apple frameworks and APIs.
4. Use Sosumi to research and verify current Apple documentation when APIs, behavior, design, or platform conventions are relevant.
5. Use the appropriate installed specialist skills.
6. Prefer the newest appropriate APIs for the target SDK.
7. Respect availability requirements and provide appropriate fallbacks when the deployment target requires them.
8. Never invent, assume, or hallucinate an Apple API.

## Code Quality

Always create the most optimized and performant, stable and reliable, concise yet powerful code possible.

Prioritize:

* Excellent runtime performance.
* Efficient memory usage.
* Stable and reliable behavior.
* Minimal unnecessary work and recomputation.
* Clear and maintainable architecture.
* Concise implementations without sacrificing clarity.
* Native Apple APIs and platform capabilities.
* Appropriate separation of concerns.
* Minimal unnecessary abstraction.
* Minimal duplication.
* Robust error handling where genuinely necessary.
* Correct concurrency and data flow.
* Correct SwiftUI identity and state management.
* Code that is easy for another developer or agent to understand and maintain.

Do not optimize prematurely at the expense of readability or correctness. Prefer simple, native, well-designed solutions when they provide equivalent or better performance and reliability.

Do not add unnecessary frameworks, dependencies, abstractions, wrappers, or infrastructure when Apple's native APIs can solve the problem cleanly.

## UI and Design

For UI work:

* Apply Apple's Human Interface Guidelines.
* Use Sosumi to research relevant HIG guidance and Apple design conventions.
* Use native SwiftUI/UIKit/AppKit components whenever appropriate.
* Prefer Apple's existing components and behaviors over unnecessarily custom implementations.
* Prioritize clean, elegant, gorgeous, and fluid results without sacrificing correctness, maintainability, accessibility, or platform conventions.
* Make interfaces feel genuinely native to the target Apple platform rather than merely resembling an Apple interface.
* Respect platform-specific layout, navigation, typography, spacing, materials, controls, and interaction patterns.
* Check accessibility, Dynamic Type, VoiceOver, contrast, localization, safe areas, keyboard interaction, pointer interaction, and relevant platform conventions.
* For Liquid Glass, use `liquid-glass` and `liquid-glass-motion` and verify current behavior and availability through Sosumi.
* For animation and interaction, use `apple-motion-feel` and verify appropriate behavior through Sosumi.
* Review animation, spring behavior, gesture handoff, interruption, Reduce Motion, and performance.
* Avoid unnecessary custom controls when an appropriate system component exists.

The final result should feel polished, intentional, responsive, and native.

## Current API and Documentation Verification

Current Apple documentation takes precedence over model memory.

When implementing or reviewing an API:

1. Search Sosumi for the relevant Apple documentation.
2. Verify the API name, signature, availability, platform support, and intended usage.
3. Check relevant WWDC guidance when implementation or design decisions benefit from it.
4. Check Human Interface Guidelines when the decision affects user experience or interaction design.
5. Implement according to the current verified guidance.
6. Do not substitute an older API merely because it is more familiar.

When current Apple guidance is unavailable or ambiguous, state the uncertainty internally and choose the most conservative verified implementation rather than inventing behavior.

## Final Verification Workflow

After implementation, always follow this workflow:

1. Ensure the project builds successfully.
2. Discover all available Apple devices and targets rather than assuming a particular device.
3. Install and run on the most appropriate available real target.
4. If no appropriate real target is available, simply build and run the app through Simulator.
5. Ensure the app launches successfully and does not crash.
6. Exit once the above verification is complete.

Use the available Xcode MCP and `device-interaction` capabilities when appropriate for device discovery, installation, and execution.

Do not assume a particular device model. Always discover the currently available targets.

If a real device is available and appropriate, prefer it over Simulator for normal verification.

If no appropriate real device is available, use Simulator rather than inventing or assuming another target.

## Screenshot Workflow

Only perform this workflow when the user specifically asks for a screenshot.

1. Build the project.
2. Run the app via Simulator.
3. Navigate only if necessary to reach the requested screen/state.
4. Take the requested screenshot.
5. Save/upload the screenshot to the project's `Screenshots` folder.
6. Exit.

Do not perform screenshot or image analysis. Do not expect the model to interpret screenshots.

Do not attach screenshots or other files to the conversation unless the user explicitly asks for them or they are genuinely required for debugging a problem or build failure.

## Simulator Cleanup

If Simulator is launched or triggered at any point during a task, ensure that Simulator is shut down before exiting the task.

This applies even if the task encounters a failure after Simulator has been launched.

Do not leave Simulator processes running unnecessarily after the task is complete.

## Debugging Discipline

Do not perform unnecessary debugging, diagnostics, logging, or additional investigation when the build and run succeed.

Only debug when there is a genuine problem, such as:

* A build failure.
* A compilation error.
* A runtime failure.
* A crash.
* An installation failure.
* A launch failure.
* An API or platform incompatibility preventing the requested task from working.
* Another concrete issue preventing successful completion.

When a genuine problem occurs:

1. Identify the actual failure.
2. Gather only the diagnostics necessary to understand it.
3. Fix the underlying issue.
4. Rebuild.
5. Re-run.
6. Verify that the issue is resolved.
7. Stop once successful.

Do not perform speculative debugging or unnecessary diagnostics after successful verification.

## Completion Standard

A task is complete when the requested implementation is finished, the project builds successfully, and the required run/installation verification has succeeded.

For UI tasks, correctness includes native platform behavior, visual quality, accessibility, performance, and appropriate Apple design conventions.

Do not add unnecessary work after the task has successfully met these requirements.
