//
//  CustomPlayerViewController.swift
//  MediaMio
//
//  Complete custom video player using AVPlayerLayer for full control on tvOS
//

import UIKit
import AVKit
import Combine

class CustomPlayerViewController: UIViewController {

    // MARK: - Properties

    var viewModel: VideoPlayerViewModel!
    var onClose: (() -> Void)?
    var onShowSubtitlePicker: (() -> Void)?
    var onShowBitratePicker: (() -> Void)?

    // Player Layer
    private var playerLayer: AVPlayerLayer!

    // Controls Container
    private let controlsContainer = UIView()
    private var isControlsVisible = true
    private var hideControlsTimer: Timer?

    // Top Bar
    private let topBarContainer = UIView()
    private let titleLabel = UILabel()
    private let metadataLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    // Center Controls
    private let centerControlsContainer = UIView()
    private let seekBackwardButton = UIButton(type: .system)
    private let playPauseButton = UIButton(type: .system)
    private let seekForwardButton = UIButton(type: .system)

    // Bottom Bar
    private let bottomBarContainer = UIView()
    private let currentTimeLabel = UILabel()
    private let remainingTimeLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let subtitleButton = UIButton(type: .system)
    private let bitrateButton = UIButton(type: .system)
    private let audioButton = UIButton(type: .system)

    // Gradient
    private let gradientView = UIView()

    // Cancellables
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎮 CustomPlayerViewController.viewDidLoad()")

        view.backgroundColor = .black

        setupPlayerLayer()
        setupGradient()
        setupControlsContainer()
        setupTopBar()
        setupCenterControls()
        setupBottomBar()
        setupGestures()
        setupObservers()

        // Show controls initially
        showControls()

        print("✅ CustomPlayerViewController setup complete")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🎮 CustomPlayerViewController.viewDidAppear()")

        // Set focus to play/pause button
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds

        // Update gradient frame
        if let gradientLayer = gradientView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = view.bounds
        }
    }

    // MARK: - Player Layer Setup

    private func setupPlayerLayer() {
        guard let player = viewModel?.player else {
            print("⚠️ No player available for layer")
            return
        }

        print("📺 Setting up AVPlayerLayer")
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = view.bounds
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)

        print("   ✅ AVPlayerLayer added to view")
    }

    // MARK: - UI Setup

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

    private func setupControlsContainer() {
        controlsContainer.backgroundColor = .clear
        controlsContainer.alpha = 1.0  // Start visible
        view.addSubview(controlsContainer)

        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsContainer.topAnchor.constraint(equalTo: view.topAnchor),
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupTopBar() {
        // Title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 36)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.text = viewModel?.item.name ?? ""

        // Metadata
        metadataLabel.font = UIFont.systemFont(ofSize: 20)
        metadataLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        if let seriesName = viewModel?.item.seriesName,
           let seasonNum = viewModel?.item.parentIndexNumber,
           let episodeNum = viewModel?.item.indexNumber {
            metadataLabel.text = "\(seriesName) · S\(seasonNum):E\(episodeNum)"
        }

        // Close button
        var closeConfig = UIButton.Configuration.filled()
        closeConfig.image = UIImage(systemName: "xmark")
        closeConfig.baseBackgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeConfig.baseForegroundColor = .white
        closeConfig.cornerStyle = .capsule
        closeConfig.buttonSize = .large
        closeButton.configuration = closeConfig
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .primaryActionTriggered)

        topBarContainer.addSubview(titleLabel)
        topBarContainer.addSubview(metadataLabel)
        topBarContainer.addSubview(closeButton)
        controlsContainer.addSubview(topBarContainer)

        // Layout
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        metadataLabel.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        topBarContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topBarContainer.topAnchor.constraint(equalTo: controlsContainer.safeAreaLayoutGuide.topAnchor, constant: 60),
            topBarContainer.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 60),
            topBarContainer.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -60),
            topBarContainer.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: topBarContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -20),

            metadataLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            metadataLabel.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor),

            closeButton.topAnchor.constraint(equalTo: topBarContainer.topAnchor),
            closeButton.trailingAnchor.constraint(equalTo: topBarContainer.trailingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 60),
            closeButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func setupCenterControls() {
        // Seek Backward
        var seekBackConfig = UIButton.Configuration.filled()
        seekBackConfig.image = UIImage(systemName: "gobackward.10")
        seekBackConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 40)
        seekBackConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.3)
        seekBackConfig.baseForegroundColor = .white
        seekBackConfig.cornerStyle = .capsule
        seekBackConfig.buttonSize = .large
        seekBackwardButton.configuration = seekBackConfig
        seekBackwardButton.addTarget(self, action: #selector(seekBackwardTapped), for: .primaryActionTriggered)

        // Play/Pause
        var playPauseConfig = UIButton.Configuration.filled()
        playPauseConfig.image = UIImage(systemName: "play.fill")
        playPauseConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 50)
        playPauseConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.3)
        playPauseConfig.baseForegroundColor = .white
        playPauseConfig.cornerStyle = .capsule
        playPauseConfig.buttonSize = .large
        playPauseButton.configuration = playPauseConfig
        playPauseButton.addTarget(self, action: #selector(playPauseButtonTapped), for: .primaryActionTriggered)

        // Seek Forward
        var seekForwardConfig = UIButton.Configuration.filled()
        seekForwardConfig.image = UIImage(systemName: "goforward.10")
        seekForwardConfig.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 40)
        seekForwardConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.3)
        seekForwardConfig.baseForegroundColor = .white
        seekForwardConfig.cornerStyle = .capsule
        seekForwardConfig.buttonSize = .large
        seekForwardButton.configuration = seekForwardConfig
        seekForwardButton.addTarget(self, action: #selector(seekForwardTapped), for: .primaryActionTriggered)

        centerControlsContainer.addSubview(seekBackwardButton)
        centerControlsContainer.addSubview(playPauseButton)
        centerControlsContainer.addSubview(seekForwardButton)
        controlsContainer.addSubview(centerControlsContainer)

        // Layout
        seekBackwardButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        seekForwardButton.translatesAutoresizingMaskIntoConstraints = false
        centerControlsContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            centerControlsContainer.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            centerControlsContainer.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            centerControlsContainer.widthAnchor.constraint(equalToConstant: 500),
            centerControlsContainer.heightAnchor.constraint(equalToConstant: 100),

            seekBackwardButton.leadingAnchor.constraint(equalTo: centerControlsContainer.leadingAnchor),
            seekBackwardButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            seekBackwardButton.widthAnchor.constraint(equalToConstant: 100),
            seekBackwardButton.heightAnchor.constraint(equalToConstant: 100),

            playPauseButton.centerXAnchor.constraint(equalTo: centerControlsContainer.centerXAnchor),
            playPauseButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 120),
            playPauseButton.heightAnchor.constraint(equalToConstant: 120),

            seekForwardButton.trailingAnchor.constraint(equalTo: centerControlsContainer.trailingAnchor),
            seekForwardButton.centerYAnchor.constraint(equalTo: centerControlsContainer.centerYAnchor),
            seekForwardButton.widthAnchor.constraint(equalToConstant: 100),
            seekForwardButton.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func setupBottomBar() {
        // Time labels
        currentTimeLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        currentTimeLabel.textColor = .white
        currentTimeLabel.text = "0:00"

        remainingTimeLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        remainingTimeLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        remainingTimeLabel.text = "-0:00"

        // Progress bar
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.3)

        // Subtitle button
        var subtitleConfig = UIButton.Configuration.filled()
        subtitleConfig.title = "Subtitles"
        subtitleConfig.image = UIImage(systemName: "captions.bubble")
        subtitleConfig.imagePadding = 8
        subtitleConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.2)
        subtitleConfig.baseForegroundColor = .white
        subtitleConfig.cornerStyle = .medium
        subtitleConfig.buttonSize = .large
        subtitleButton.configuration = subtitleConfig
        subtitleButton.addTarget(self, action: #selector(subtitleButtonTapped), for: .primaryActionTriggered)

        // Bitrate button
        var bitrateConfig = UIButton.Configuration.filled()
        bitrateConfig.title = "120 Mbps"
        bitrateConfig.image = UIImage(systemName: "gauge.high")
        bitrateConfig.imagePadding = 8
        bitrateConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.2)
        bitrateConfig.baseForegroundColor = .white
        bitrateConfig.cornerStyle = .medium
        bitrateConfig.buttonSize = .large
        bitrateButton.configuration = bitrateConfig
        bitrateButton.addTarget(self, action: #selector(bitrateButtonTapped), for: .primaryActionTriggered)

        // Audio button
        var audioConfig = UIButton.Configuration.filled()
        audioConfig.title = "Audio"
        audioConfig.image = UIImage(systemName: "speaker.wave.2")
        audioConfig.imagePadding = 8
        audioConfig.baseBackgroundColor = UIColor.white.withAlphaComponent(0.2)
        audioConfig.baseForegroundColor = .white
        audioConfig.cornerStyle = .medium
        audioConfig.buttonSize = .large
        audioButton.configuration = audioConfig
        audioButton.addTarget(self, action: #selector(audioButtonTapped), for: .primaryActionTriggered)

        bottomBarContainer.addSubview(currentTimeLabel)
        bottomBarContainer.addSubview(remainingTimeLabel)
        bottomBarContainer.addSubview(progressView)
        bottomBarContainer.addSubview(subtitleButton)
        bottomBarContainer.addSubview(bitrateButton)
        bottomBarContainer.addSubview(audioButton)
        controlsContainer.addSubview(bottomBarContainer)

        // Layout
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        remainingTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        subtitleButton.translatesAutoresizingMaskIntoConstraints = false
        bitrateButton.translatesAutoresizingMaskIntoConstraints = false
        audioButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBarContainer.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bottomBarContainer.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 60),
            bottomBarContainer.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -60),
            bottomBarContainer.bottomAnchor.constraint(equalTo: controlsContainer.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            bottomBarContainer.heightAnchor.constraint(equalToConstant: 120),

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
            subtitleButton.heightAnchor.constraint(equalToConstant: 60),
            subtitleButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),

            bitrateButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            bitrateButton.trailingAnchor.constraint(equalTo: subtitleButton.leadingAnchor, constant: -20),
            bitrateButton.heightAnchor.constraint(equalToConstant: 60),
            bitrateButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),

            audioButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            audioButton.trailingAnchor.constraint(equalTo: bitrateButton.leadingAnchor, constant: -20),
            audioButton.heightAnchor.constraint(equalToConstant: 60),
            audioButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
    }

    // MARK: - Gestures

    private func setupGestures() {
        // Select gesture (tap on remote)
        let selectTap = UITapGestureRecognizer(target: self, action: #selector(handleSelect))
        selectTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        view.addGestureRecognizer(selectTap)

        // Play/Pause button
        let playPauseTap = UITapGestureRecognizer(target: self, action: #selector(handlePlayPause))
        playPauseTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        view.addGestureRecognizer(playPauseTap)

        // Menu button
        let menuTap = UITapGestureRecognizer(target: self, action: #selector(handleMenu))
        menuTap.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menuTap)
    }

    // MARK: - Observers

    private func setupObservers() {
        // Observe isPlaying changes
        viewModel?.$isPlaying
            .sink { [weak self] isPlaying in
                self?.updatePlayPauseButton()
                if isPlaying {
                    self?.hideControlsAfterDelay()
                }
            }
            .store(in: &cancellables)

        // Observe progress changes
        viewModel?.$progress
            .sink { [weak self] _ in
                self?.updateProgress()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func handleSelect() {
        print("🎮 Select pressed")
        toggleControls()
    }

    @objc private func handlePlayPause() {
        print("🎮 Play/Pause pressed")
        viewModel?.togglePlayPause()
        showControls()
    }

    @objc private func handleMenu() {
        print("🎮 Menu pressed")
        if isControlsVisible {
            hideControls()
        } else {
            onClose?()
        }
    }

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

    // MARK: - Controls Visibility

    private func toggleControls() {
        if isControlsVisible {
            hideControls()
        } else {
            showControls()
        }
    }

    private func showControls() {
        print("🎮 Showing controls")
        isControlsVisible = true

        UIView.animate(withDuration: 0.3) {
            self.controlsContainer.alpha = 1.0
        }

        // Set focus to play/pause button
        setNeedsFocusUpdate()
        updateFocusIfNeeded()

        resetHideTimer()
    }

    private func hideControls() {
        print("🎮 Hiding controls")
        isControlsVisible = false

        UIView.animate(withDuration: 0.3) {
            self.controlsContainer.alpha = 0.0
        }

        hideControlsTimer?.invalidate()
        hideControlsTimer = nil
    }

    private func resetHideTimer() {
        hideControlsTimer?.invalidate()

        let isPlaying = viewModel?.isPlaying ?? false
        guard isPlaying else {
            print("   ⏸️  Video paused, not scheduling hide timer")
            return
        }

        print("   ⏰ Scheduling hide timer for 5 seconds")
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            print("   ⏰ Hide timer fired!")
            self?.hideControls()
        }
    }

    private func hideControlsAfterDelay() {
        resetHideTimer()
    }

    // MARK: - Update UI

    private func updateProgress() {
        guard let viewModel = viewModel else { return }

        currentTimeLabel.text = viewModel.currentTimeFormatted
        remainingTimeLabel.text = viewModel.remainingTimeFormatted
        progressView.progress = Float(viewModel.progress)
    }

    private func updatePlayPauseButton() {
        let isPlaying = viewModel?.isPlaying ?? false
        let iconName = isPlaying ? "pause.fill" : "play.fill"

        var config = playPauseButton.configuration
        config?.image = UIImage(systemName: iconName)
        playPauseButton.configuration = config
    }

    // MARK: - Focus Management (CRITICAL for tvOS)

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if isControlsVisible {
            return [playPauseButton]
        } else {
            return [view]
        }
    }
}
