import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Wraps a card with swipe actions: swipe right to complete, left to reveal
/// Snooze and Delete. Works inside a `ScrollView` without blocking scrolling.
struct SwipeableRow<Content: View>: View {
    let item: JotItem
    /// The row currently swiped open; opening one closes the others.
    @Binding var openRow: UUID?
    var onComplete: () -> Void
    var onSnooze: (SnoozeOption) -> Void
    var onDelete: () -> Void
    @ViewBuilder let content: Content

    @Environment(\.jotAnimation) private var animation
    @State private var offset: CGFloat = 0
    @State private var restingOffset: CGFloat = 0
    @State private var pastCompleteThreshold = false
    @State private var showingSnooze = false

    private let completeThreshold: CGFloat = 90
    private let actionWidth: CGFloat = 64

    private var canComplete: Bool { ItemActions.canComplete(item) }
    private var canSnooze: Bool { ItemActions.canSnooze(item) }
    private var trailingWidth: CGFloat { actionWidth * (canSnooze ? 2 : 1) + 8 }
    private var isOpen: Bool { restingOffset != 0 }

    var body: some View {
        ZStack {
            actionsBackground
            content
                .overlay {
                    if isOpen {
                        // While open, a tap anywhere on the card just closes it.
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture { close() }
                    }
                }
                // After the overlay, so the tap catcher slides with the card
                // and doesn't cover the revealed buttons.
                .offset(x: offset)
        }
        .gesture(pan)
        .onChange(of: openRow) { _, id in
            if id != item.id, isOpen { close() }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: pastCompleteThreshold) { _, crossed in crossed }
        .confirmationDialog("Snooze until…", isPresented: $showingSnooze, titleVisibility: .visible) {
            ForEach(SnoozeOption.available()) { option in
                Button(option.label) {
                    close()
                    onSnooze(option)
                }
            }
        }
        .accessibilityActions {
            if canComplete {
                Button(item.isCompleted ? "Reopen" : "Complete", action: onComplete)
            }
            if canSnooze {
                ForEach(SnoozeOption.available()) { option in
                    Button("Snooze: \(option.label)") { onSnooze(option) }
                }
            }
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    // MARK: Background actions

    private var actionsBackground: some View {
        HStack(spacing: 8) {
            if canComplete, offset > 0 {
                let progress = min(offset / completeThreshold, 1)
                Image(systemName: item.isCompleted ? "arrow.uturn.backward" : "checkmark")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.jotBackground)
                    .frame(width: 48, height: 48)
                    .background(Color.jotTask, in: .circle)
                    .scaleEffect(0.5 + progress * 0.5 + (pastCompleteThreshold ? 0.12 : 0))
                    .opacity(Double(progress))
                    .padding(.leading, 12)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            if offset < 0 {
                if canSnooze {
                    actionButton("Snooze", symbol: "clock.fill", color: .jotReminder) {
                        showingSnooze = true
                    }
                }
                actionButton("Delete", symbol: "trash.fill", color: .red) {
                    close()
                    onDelete()
                }
            }
        }
        .padding(.trailing, 4)
    }

    private func actionButton(_ title: String, symbol: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 46, height: 46)
                    .background(color.opacity(0.16), in: .circle)
                    .overlay(Circle().strokeBorder(color.opacity(0.35), lineWidth: 1))
                Text(title)
                    .font(.jotLabel)
                    .foregroundStyle(Color.jotTextSecondary)
            }
            .frame(width: actionWidth)
        }
        .buttonStyle(.pressable)
        .opacity(min(Double(-offset / trailingWidth), 1))
    }

    // MARK: Gesture

    private var pan: HorizontalPan {
        HorizontalPan { translation in
            var proposed = restingOffset + translation
            if !canComplete { proposed = min(proposed, 0) }
            // Rubber-band past the natural stops.
            if proposed < -trailingWidth {
                proposed = -trailingWidth - (-trailingWidth - proposed) * 0.25
            }
            offset = proposed
            pastCompleteThreshold = canComplete && proposed > completeThreshold
            if proposed != 0, openRow != item.id { openRow = item.id }
        } onEnded: { translation, velocity in
            let final = restingOffset + translation
            if canComplete, final > completeThreshold || (final > 40 && velocity > 600) {
                withAnimation(animation) { offset = 0; restingOffset = 0 }
                pastCompleteThreshold = false
                onComplete()
            } else if final < -trailingWidth / 2 || velocity < -600 {
                withAnimation(animation) { offset = -trailingWidth; restingOffset = -trailingWidth }
            } else {
                close()
            }
        }
    }

    private func close() {
        withAnimation(animation) {
            offset = 0
            restingOffset = 0
        }
        pastCompleteThreshold = false
        if openRow == item.id { openRow = nil }
    }
}

#if canImport(UIKit)
/// A pan that only begins for mostly-horizontal drags, so vertical scrolling is untouched.
struct HorizontalPan: UIGestureRecognizerRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (_ translation: CGFloat, _ velocity: CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed:
            onChanged(translation)
        case .ended, .cancelled, .failed:
            onEnded(translation, recognizer.velocity(in: recognizer.view).x)
        default:
            break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.4
        }
    }
}
#endif
