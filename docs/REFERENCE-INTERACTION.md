# Reference interaction and native input contract

Two videos supplied by the project owner were visually inspected during development. The videos and extracted contact sheets are excluded from this repository; they are third-party reference material with no redistribution license granted here. They are evidence of desired visual behavior, not instructions to execute, and do not establish how the reference application stores or moves Finder files. All bundled textile patterns are original procedural drawings.

## Visible behavior to reproduce

The first contact sheet shows a rug resting flat, a corner folded inward across a diagonal crease, the fold releasing toward a flat state, and desktop icons becoming visible wherever cloth no longer covers them. The second shows large local folds during dragging: the grabbed region travels first, the remaining fabric follows with delay, and the rug falls back onto the desktop with residual deformation. The border, medallion, and woven pattern follow those deformations; the shape is not a rigid rectangular image.

For Desktop Mat, the requested behavior remains non-destructive: a native transparent overlay covers existing desktop pixels. The application must not rename, move, delete, reorder, or otherwise modify Finder files. Visual correspondence to the reference does not require copying its textile design, wallpaper, screen capture, or file manipulation.

Acceptance observations:

1. A mouse-down in the middle grabs cloth locally. Dragging causes neighboring mesh vertices to follow through physical constraints.
2. A mouse-down near a mesh corner lifts that corner. The actual projected mesh shrinks or folds away, exposing desktop pixels.
3. Releasing the button releases the physical constraint, allows gravity and damping to settle the cloth, and restores passive input outside the resulting mesh.
4. A normal application window remains above the rug. Mouse actions in that application retain normal ownership.
5. The transparent part of the overlay passes mouse actions to Finder. Shadows and the original rectangular rug bounds are not input targets.

## Public AppKit input contract

Use a borderless nonactivating `NSPanel` at the existing desktop window level. `ignoresMouseEvents` controls window-wide mouse transparency. A mesh hit test in `NSView.hitTest` alone cannot reliably route an action through the window to Finder, so the window's mouse transparency must be set before the WindowServer chooses the target. This last conclusion is an implementation inference from the window-level API, and must be verified on a real desktop. [Apple: ignoresMouseEvents](https://developer.apple.com/documentation/appkit/nswindow/ignoresmouseevents)

The view accepts the first mouse-down, handles `mouseDown`, `mouseDragged`, and `mouseUp`, and keeps a single input owner for the whole drag. The rug panel never becomes key or main. [Apple: Handling Mouse Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/HandlingMouseEvents/HandlingMouseEvents.html)

Install both local and global monitors for pointer movement and release observations. Global monitoring receives copies of other applications' events asynchronously and cannot prevent their original delivery; local monitoring observes this application's dispatch. Keyboard monitoring has additional Accessibility requirements. Remove monitor tokens explicitly when no longer needed. [Apple: Monitoring Events](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html)

## Input ownership and edge cases

- Start a drag only from an actual `mouseDown` delivered to the rug view. Never turn a global Finder mouse-down into a second cloth drag: the original click has already reached Finder.
- While a cloth drag is active, preserve the originating panel as the only capture owner, even when the pointer crosses its frame or another monitor. Continue using the owner's screen-to-local conversion. The other panels must remain passive during that drag.
- Do not activate capture on a rug merely because a pressed mouse enters it. That mouse-down might belong to a Finder file drag or another application.
- Use local/global mouse-up observations as a release fallback. A current-button-state poll may cancel a stale grab after release; it must not synthesize a new drag. The local SDK's `NSEvent.h` explicitly distinguishes current button state from queued events and says it is unsuitable for tracking.
- `NSEvent.mouseLocation` and `NSScreen.frame` are AppKit screen coordinates. Convert using `NSWindow.convertPoint(fromScreen:)`, then `NSView.convert(_:from: nil)`. Preserve negative display origins. Apply an explicit Y flip only at the boundary of a top-left simulation/rendering coordinate system. Do not mix CoreGraphics event coordinates into this path.
- Retina backing scale affects drawable pixels, not logical mouse positions. Mesh projection used for rendering and hit tests must share the same logical projection before pixel scaling.
- First-click capture has a timing boundary: an asynchronous hover callback cannot change the target of a click already dispatched. A frequent hover poll improves responsiveness, but does not prove lossless capture. Test fast entry-and-click and direct exposed-file clicks without cursor movement.
- Timer and monitor closures must avoid retain cycles. Stop timers, remove monitors, release active grabs, and restore owned cursor state on hide, shutdown, display removal, or reconstruction. Schedule a polling timer in common run-loop modes if it is expected to run while a menu is open.
- Only change the hand cursor when the rug is actually the frontmost mouse target; checking mesh coverage alone also matches rugs behind foreground windows. Avoid pushing a cursor on every poll. A cursor stack needs one explicit owner and balanced push/pop at all exit paths.

The API declarations and monitor caveats above were cross-checked with the installed Xcode SDK's `AppKit.framework/Headers/NSEvent.h`, `NSWindow.h`, `NSView.h`, and `NSPanel.h` on 2026-10-07. macOS 15 desktop behavior still needs runtime validation; documentation alone does not prove Space switching, WindowServer routing, or file click-through.
