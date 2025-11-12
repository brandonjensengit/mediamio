//
//  FocusGuideViewController.swift
//  MediaMio
//
//  Created by Claude Code
//  UIKit Focus Guides for Netflix-style navigation
//

import UIKit
import SwiftUI

/// UIKit view controller that manages UIFocusGuides for smooth navigation
/// between hero and content rows (Netflix-style)
@MainActor
class FocusGuideViewController: UIHostingController<AnyView> {
    // MARK: - Focus Guides

    private var focusGuides: [UIFocusGuide] = []
    private let focusManager: FocusManager

    // MARK: - Focus Sections (estimated positions)

    /// Estimated frame for hero section
    private var heroFrame: CGRect = .zero

    /// Estimated frames for each row section
    private var rowFrames: [CGRect] = []

    // MARK: - Initialization

    init(rootView: AnyView, focusManager: FocusManager) {
        self.focusManager = focusManager
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🎯 FocusGuideViewController: viewDidLoad")

        // Setup focus guides after layout
        DispatchQueue.main.async {
            self.setupFocusGuides()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Update focus guide positions when layout changes
        updateFocusGuidePositions()
    }

    // MARK: - Focus Guide Setup

    private func setupFocusGuides() {
        print("🎯 Setting up focus guides...")

        // Clear existing guides
        focusGuides.forEach { $0.removeFromSuperview() }
        focusGuides.removeAll()

        // Estimate section positions
        estimateSectionPositions()

        // Create guide from hero to first row
        if !rowFrames.isEmpty {
            let heroToFirstRowGuide = createFocusGuide(
                from: heroFrame,
                to: rowFrames[0],
                preferredFocusEnvironment: view,
                identifier: "hero-to-row-0"
            )
            focusGuides.append(heroToFirstRowGuide)
        }

        // Create guides between rows
        for i in 0..<(rowFrames.count - 1) {
            let currentFrame = rowFrames[i]
            let nextFrame = rowFrames[i + 1]

            // Guide from current row down to next row
            let downGuide = createFocusGuide(
                from: currentFrame,
                to: nextFrame,
                preferredFocusEnvironment: view,
                identifier: "row-\(i)-to-row-\(i+1)"
            )
            focusGuides.append(downGuide)

            // Guide from next row up to current row
            let upGuide = createFocusGuide(
                from: nextFrame,
                to: currentFrame,
                preferredFocusEnvironment: view,
                identifier: "row-\(i+1)-to-row-\(i)"
            )
            focusGuides.append(upGuide)
        }

        // Create guide from first row back to hero
        if !rowFrames.isEmpty {
            let firstRowToHeroGuide = createFocusGuide(
                from: rowFrames[0],
                to: heroFrame,
                preferredFocusEnvironment: view,
                identifier: "row-0-to-hero"
            )
            focusGuides.append(firstRowToHeroGuide)
        }

        print("✅ Created \(focusGuides.count) focus guides")
    }

    private func createFocusGuide(
        from sourceFrame: CGRect,
        to targetFrame: CGRect,
        preferredFocusEnvironment: UIView,
        identifier: String
    ) -> UIFocusGuide {
        let guide = UIFocusGuide()
        view.addLayoutGuide(guide)

        // Position the guide between source and target
        // For vertical navigation, place guide at bottom of source or top of target
        let isDownward = sourceFrame.minY < targetFrame.minY

        NSLayoutConstraint.activate([
            guide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            guide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            guide.topAnchor.constraint(
                equalTo: view.topAnchor,
                constant: isDownward ? sourceFrame.maxY : targetFrame.maxY
            ),
            guide.heightAnchor.constraint(equalToConstant: 1)
        ])

        // The guide doesn't directly set preferred focus environments
        // Instead, focus engine uses it as a navigation hint
        // We'll handle preferred focus through SwiftUI's @FocusState

        print("🎯 Created focus guide: \(identifier)")
        return guide
    }

    private func estimateSectionPositions() {
        // Rough estimates based on typical layout
        // Hero: 0-900
        // First row: ~940-1200
        // Subsequent rows: +260 each (with spacing)

        let safeArea = view.safeAreaInsets

        heroFrame = CGRect(
            x: safeArea.left,
            y: safeArea.top,
            width: view.bounds.width - safeArea.left - safeArea.right,
            height: 900  // Hero height
        )

        // Estimate up to 10 rows
        let firstRowTop: CGFloat = 940
        let rowSpacing: CGFloat = 260

        rowFrames = (0..<10).map { index in
            CGRect(
                x: safeArea.left,
                y: firstRowTop + CGFloat(index) * rowSpacing,
                width: view.bounds.width - safeArea.left - safeArea.right,
                height: 220  // Row height
            )
        }
    }

    private func updateFocusGuidePositions() {
        // Update guide positions if needed
        // This is called when layout changes (rotation, etc)
        estimateSectionPositions()
    }

    // MARK: - Focus Updates

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        // Track focus changes
        if let nextFocused = context.nextFocusedView {
            print("🎯 Focus moved to: \(nextFocused)")
        }

        // Animate focus transitions
        coordinator.addCoordinatedAnimations({
            // Scale focused element
            if let nextView = context.nextFocusedView {
                nextView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }

            // Reset previous element
            if let prevView = context.previouslyFocusedView {
                prevView.transform = .identity
            }
        }, completion: nil)
    }

    // MARK: - Preferred Focus

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        // Start with hero (Play button)
        // SwiftUI will handle the actual button focus through @FocusState
        return [view]
    }
}
