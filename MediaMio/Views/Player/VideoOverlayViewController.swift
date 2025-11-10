//
//  VideoOverlayViewController.swift
//  MediaMio
//
//  UIKit overlay for AVPlayerViewController to enable proper focus navigation
//  Apple requires customOverlayViewController (not SwiftUI ZStack) for interactive controls
//

import UIKit
import AVKit

/// UIKit overlay view controller for video player controls
/// This is required because AVPlayerViewController blocks focus from SwiftUI overlays
class VideoOverlayViewController: UIViewController {

    // MARK: - Properties

    weak var viewModel: VideoPlayerViewModel?
    var onClose: (() -> Void)?
    var onShowSubtitlePicker: (() -> Void)?
    var onShowBitratePicker: (() -> Void)?

    private var isVisible = false
    private var hideTimer: Timer?

    // MARK: - UI Components

    // Top bar
    private let titleLabel = UILabel()
    private let metadataLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    // Center controls
    private let seekBackwardButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let seekForwardButton = UIButton(type: .system)

    // Bottom bar
    private let currentTimeLabel = UILabel()
    private let remainingTimeLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let subtitleButton = UIButton(type: .system)
    private let bitrateButton = UIButton(type: .system)
    private let audioButton = UIButton(type: .system)

    // Container views
    private let topBarContainer = UIView()
    private let centerControlsContainer = UIView()
    private let bottomBarContainer = UIView()
    private let gradientView = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // CRITICAL: Transparent background so video shows through
        view.backgroundColor = .clear

        setupGradient()
        setupTopBar()
        setupCenterControls()
        setupBottomBar()
        setupLayout()
        setupGestureRecognizers()

        // Start visible
        show()
    }

    // MARK: - Focus Management (CRITICAL for tvOS)

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        // Default focus to play/pause button
        return [playPauseButton]
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        // Show controls when any button receives focus
        if context.nextFocusedView?.isDescendant(of: view) == true {
            show()
            resetHideTimer()
        }
    }

    // MARK: - Setup

    private func setupGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.7).cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.7).cgColor
        ]
        gradientLayer.locations = [0.0, 0.4, 1.0]
        gradientLayer.frame = view.bounds
        gradientView.layer.addSublayer(gradientLayer)
        view.addSubview(gradientView)
    }

    private func setupTopBar() {
        // Title label
        titleLabel.font = UIFont.boldSystemFont(ofSize: 36)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Metadata label
        metadataLabel.font = UIFont.systemFont(ofSize: 20)
        metadataLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false

        // Close button
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 30
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .primaryActionTriggered)
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        topBarContainer.addSubview(titleLabel)
        topBarContainer.addSubview(metadataLabel)
        topBarContainer.addSubview(closeButton)
        topBarContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBarContainer)
    }

    private func setupCenterControls() {
        // Configure seek backward button
        let seekBackConfig = UIImage.SymbolConfiguration(pointSize: 60)
        seekBackwardButton.setImage(UIImage(systemName: "gobackward.10", withConfiguration: seekBackConfig), for: .normal)
        seekBackwardButton.tintColor = .white
        seekBackwardButton.addTarget(self, action: #selector(seekBackwardTapped), for: .primaryActionTriggered)
        seekBackwardButton.translatesAutoresizingMaskIntoConstraints = false

        // Configure play/pause button
        let playPauseConfig = UIImage.SymbolConfiguration(pointSize: 80)
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: playPauseConfig), for: .normal)
        playPauseButton.tintColor = .white
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .primaryActionTriggered)
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false

        // Configure seek forward button
        let seekForwardConfig = UIImage.SymbolConfiguration(pointSize: 60)
        seekForwardButton.setImage(UIImage(systemName: "goforward.10", withConfiguration: seekForwardConfig), for: .normal)
        seekForwardButton.tintColor = .white
        seekForwardButton.addTarget(self, action: #selector(seekForwardTapped), for: .primaryActionTriggered)
        seekForwardButton.translatesAutoresizingMaskIntoConstraints = false

        centerControlsContainer.addSubview(seekBackwardButton)
        centerControlsContainer.addSubview(playPauseButton)
        centerControlsContainer.addSubview(seekForwardButton)
        centerControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(centerControlsContainer)
    }

    private func setupBottomBar() {
        // Time labels
        currentTimeLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        currentTimeLabel.textColor = .white
        currentTimeLabel.text = "0:00"
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        remainingTimeLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        remainingTimeLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        remainingTimeLabel.text = "-0:00"
        remainingTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        // Progress bar
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.translatesAutoresizingMaskIntoConstraints = false

        // Subtitle button
        subtitleButton.setTitle("  Subtitles", for: .normal)
        subtitleButton.setImage(UIImage(systemName: "captions.bubble"), for: .normal)
        subtitleButton.tintColor = .white
        subtitleButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        subtitleButton.layer.cornerRadius = 8
        subtitleButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        subtitleButton.addTarget(self, action: #selector(subtitleButtonTapped), for: .primaryActionTriggered)
        subtitleButton.translatesAutoresizingMaskIntoConstraints = false

        // Bitrate button
        bitrateButton.setTitle("  120 Mbps", for: .normal)
        bitrateButton.setImage(UIImage(systemName: "gauge.high"), for: .normal)
        bitrateButton.tintColor = .white
        bitrateButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        bitrateButton.layer.cornerRadius = 8
        bitrateButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        bitrateButton.addTarget(self, action: #selector(bitrateButtonTapped), for: .primaryActionTriggered)
        bitrateButton.translatesAutoresizingMaskIntoConstraints = false

        // Audio button
        audioButton.setTitle("  Audio", for: .normal)
        audioButton.setImage(UIImage(systemName: "speaker.wave.2"), for: .normal)
        audioButton.tintColor = .white
        audioButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        audioButton.layer.cornerRadius = 8
        audioButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        audioButton.addTarget(self, action: #selector(audioButtonTapped), for: .primaryActionTriggered)
        audioButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBarContainer.addSubview(currentTimeLabel)
        bottomBarContainer.addSubview(remainingTimeLabel)
        bottomBarContainer.addSubview(progressView)
        bottomBarContainer.addSubview(subtitleButton)
        bottomBarContainer.addSubview(bitrateButton)
        bottomBarContainer.addSubview(audioButton)
        bottomBarContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBarContainer)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            // Gradient (full screen)
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Top bar
            topBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            topBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            topBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            topBarContainer.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: topBarContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -20),

            metadataLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            metadataLabel.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor),

            closeButton.topAnchor.constraint(equalTo: topBarContainer.topAnchor),
            closeButton.trailingAnchor.constraint(equalTo: topBarContainer.trailingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 60),

            // Center controls
            centerControlsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerControlsContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centerControlsContainer.heightAnchor.constraint(equalToConstant: 100),
            centerControlsContainer.widthAnchor.constraint(equalToConstant: 400),

            seekBackwardButton.leadingAnchor.constraint(equalTo: centerControlsContainer.leadingAnchor),
            seekBackwardButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            seekBackwardButton.widthAnchor.constraint(equalToConstant: 80),
            seekBackwardButton.heightAnchor.constraint(equalToConstant: 80),

            playPauseButton.centerXAnchor.constraint(equalTo: centerControlsContainer.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 100),
            playPauseButton.heightAnchor.constraint(equalToConstant: 100),

            seekForwardButton.trailingAnchor.constraint(equalTo: centerControlsContainer.trailingAnchor),
            seekForwardButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            seekForwardButton.widthAnchor.constraint(equalToConstant: 80),
            seekForwardButton.heightAnchor.constraint(equalToConstant: 80),

            // Bottom bar
            bottomBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            bottomBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -60),
            bottomBarContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            bottomBarContainer.heightAnchor.constraint(equalToConstant: 100),

            currentTimeLabel.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor),
            currentTimeLabel.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor),

            remainingTimeLabel.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor),
            remainingTimeLabel.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor),

            progressView.topAnchor.constraint(equalTo: currentTimeLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 8),

            subtitleButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            subtitleButton.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor),
            subtitleButton.heightAnchor.constraint(equalToConstant: 44),

            bitrateButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            bitrateButton.trailingAnchor.constraint(equalTo: subtitleButton.leadingAnchor, constant: -20),
            bitrateButton.heightAnchor.constraint(equalToConstant: 44),

            audioButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            audioButton.trailingAnchor.constraint(equalTo: bitrateButton.leadingAnchor, constant: -20),
            audioButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupGestureRecognizers() {
        // Menu button should show/hide controls
        let menuGesture = UITapGestureRecognizer(target: self, action: #selector(menuButtonPressed))
        menuGesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menuGesture)
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        print("🎮 Close button tapped")
        onClose?()
    }

    @objc private func seekBackwardTapped() {
        print("🎮 Seek backward tapped")
        viewModel?.seekBackward()
        resetHideTimer()
    }

    @objc private func playPauseButtonTapped() {
        print("🎮 Play/pause button tapped")
        viewModel?.togglePlayPause()
        updatePlayPauseButton()
        resetHideTimer()
    }

    @objc private func seekForwardTapped() {
        print("🎮 Seek forward tapped")
        viewModel?.seekForward()
        resetHideTimer()
    }

    @objc private func subtitleButtonTapped() {
        print("🎮 Subtitle button tapped")
        onShowSubtitlePicker?()
        resetHideTimer()
    }

    @objc private func bitrateButtonTapped() {
        print("🎮 Bitrate button tapped")
        onShowBitratePicker?()
        resetHideTimer()
    }

    @objc private func audioButtonTapped() {
        print("🎮 Audio button tapped")
        // TODO: Show audio picker
        resetHideTimer()
    }

    @objc private func menuButtonPressed() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    // MARK: - Show/Hide Controls

    func show() {
        guard !isVisible else { return }
        isVisible = true

        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }

        // Request focus update
        setNeedsFocusUpdate()
        updateFocusIfNeeded()

        resetHideTimer()
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false

        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 0.0
        }

        hideTimer?.invalidate()
        hideTimer = nil
    }

    private func resetHideTimer() {
        hideTimer?.invalidate()

        // Only auto-hide if video is playing
        guard viewModel?.isPlaying == true else { return }

        hideTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    // MARK: - Update UI

    func updateFromViewModel() {
        guard let viewModel = viewModel else { return }

        // Update title
        titleLabel.text = viewModel.item.name

        // Update metadata
        if let seriesName = viewModel.item.seriesName,
           let seasonNum = viewModel.item.parentIndexNumber,
           let episodeNum = viewModel.item.indexNumber {
            metadataLabel.text = "\(seriesName) · S\(seasonNum):E\(episodeNum)"
        }

        // Update times
        currentTimeLabel.text = viewModel.currentTimeFormatted
        remainingTimeLabel.text = viewModel.remainingTimeFormatted

        // Update progress
        progressView.progress = Float(viewModel.progress)

        // Update play/pause icon
        updatePlayPauseButton()

        // Update subtitle button
        subtitleButton.setTitle("  \(viewModel.currentSubtitleName)", for: .normal)
        if viewModel.selectedSubtitleIndex != nil {
            subtitleButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.5)
        } else {
            subtitleButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        }
    }

    private func updatePlayPauseButton() {
        let isPlaying = viewModel?.isPlaying ?? false
        let iconName = isPlaying ? "pause.fill" : "play.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 80)
        playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Update gradient frame
        if let gradientLayer = gradientView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = view.bounds
        }
    }
}
