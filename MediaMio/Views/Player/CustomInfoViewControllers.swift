//
//  CustomInfoViewControllers.swift
//  MediaMio
//
//  Custom view controllers for AVPlayerViewController.customInfoViewControllers
//

import UIKit
import AVKit

// MARK: - Bitrate Selection View Controller

class BitrateSelectionViewController: UIViewController, AVPlayerViewControllerDelegate {

    private let settingsManager: SettingsManager
    private let tableView = UITableView(frame: .zero, style: .grouped)

    private let bitrateOptions: [(label: String, value: Int)] = [
        ("Maximum (120 Mbps)", 120_000_000),
        ("High (80 Mbps)", 80_000_000),
        ("Medium (40 Mbps)", 40_000_000),
        ("Low (20 Mbps)", 20_000_000),
        ("Very Low (10 Mbps)", 10_000_000)
    ]

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        super.init(nibName: nil, bundle: nil)

        // Set preferred content size for tvOS info panel
        preferredContentSize = CGSize(width: 600, height: 400)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Video Quality"

        view.backgroundColor = .clear

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BitrateCell")
        tableView.backgroundColor = .clear
        tableView.remembersLastFocusedIndexPath = true

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        print("📊 BitrateSelectionViewController loaded with \(bitrateOptions.count) options")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Force reload data when view appears
        tableView.reloadData()
        print("📊 BitrateSelectionViewController appeared, table reloaded")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Select current bitrate
        if let index = bitrateOptions.firstIndex(where: { $0.value == settingsManager.maxBitrate }) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
}

// MARK: - UITableView Delegate & DataSource

extension BitrateSelectionViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        print("📊 numberOfSections called: returning 1")
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("📊 numberOfRowsInSection called: returning \(bitrateOptions.count)")
        return bitrateOptions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BitrateCell", for: indexPath)
        let option = bitrateOptions[indexPath.row]

        // Configure cell for tvOS
        cell.textLabel?.text = option.label
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = UIFont.systemFont(ofSize: 29, weight: .regular)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        // Show checkmark for selected option
        if option.value == settingsManager.maxBitrate {
            cell.accessoryType = .checkmark
            cell.tintColor = .white
        } else {
            cell.accessoryType = .none
        }

        print("📊 Configuring cell \(indexPath.row): \(option.label)")

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let option = bitrateOptions[indexPath.row]

        // Update settings
        settingsManager.maxBitrate = option.value

        // Reload to update checkmarks
        tableView.reloadData()

        print("📊 Bitrate changed to: \(option.label)")

        // Post notification to reload video with new bitrate
        NotificationCenter.default.post(name: NSNotification.Name("ReloadVideoWithNewBitrate"), object: nil)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Select video quality. Higher quality requires more bandwidth."
    }
}

// MARK: - Audio Quality Selection View Controller

class AudioQualitySelectionViewController: UIViewController, AVPlayerViewControllerDelegate {

    private let settingsManager: SettingsManager
    private let tableView = UITableView(frame: .zero, style: .grouped)

    private let audioQualityOptions: [(label: String, value: String)] = [
        ("Lossless (Original)", AudioQuality.lossless.rawValue),
        ("High (640 kbps)", AudioQuality.high.rawValue),
        ("Standard (192 kbps)", AudioQuality.standard.rawValue)
    ]

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        super.init(nibName: nil, bundle: nil)

        // Set preferred content size for tvOS info panel
        preferredContentSize = CGSize(width: 600, height: 400)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Audio Quality"

        view.backgroundColor = .clear

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AudioCell")
        tableView.backgroundColor = .clear
        tableView.remembersLastFocusedIndexPath = true

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        print("🔊 AudioQualitySelectionViewController loaded with \(audioQualityOptions.count) options")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Force reload data when view appears
        tableView.reloadData()
        print("🔊 AudioQualitySelectionViewController appeared, table reloaded")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Select current audio quality
        if let index = audioQualityOptions.firstIndex(where: { $0.value == settingsManager.audioQuality }) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
    }
}

// MARK: - UITableView Delegate & DataSource

extension AudioQualitySelectionViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        print("🔊 numberOfSections called: returning 1")
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("🔊 numberOfRowsInSection called: returning \(audioQualityOptions.count)")
        return audioQualityOptions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AudioCell", for: indexPath)
        let option = audioQualityOptions[indexPath.row]

        // Configure cell for tvOS
        cell.textLabel?.text = option.label
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = UIFont.systemFont(ofSize: 29, weight: .regular)
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        // Show checkmark for selected option
        if option.value == settingsManager.audioQuality {
            cell.accessoryType = .checkmark
            cell.tintColor = .white
        } else {
            cell.accessoryType = .none
        }

        print("🔊 Configuring cell \(indexPath.row): \(option.label)")

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let option = audioQualityOptions[indexPath.row]

        // Update settings
        settingsManager.audioQuality = option.value

        // Reload to update checkmarks
        tableView.reloadData()

        print("🔊 Audio quality changed to: \(option.label)")

        // Post notification to reload video with new audio quality
        NotificationCenter.default.post(name: NSNotification.Name("ReloadVideoWithNewAudioQuality"), object: nil)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Select audio quality. Changes will apply to next video."
    }
}

// MARK: - Playback Info View Controller

/// Read-only Netflix/Infuse-style "Playback Info" pane presented as the
/// third tab inside AVPlayerViewController's info panel (slide-down on
/// the remote during playback). Sections: General / Video / Audio /
/// Subtitle. The value-rendering lives in `PlaybackInfoBuilder` so this
/// view controller is just a renderer — refresh by assigning a new
/// `PlaybackInfo` via `update(info:)`, which re-reads the table.
///
/// Why UIKit instead of SwiftUI: AVPlayerViewController.customInfoViewControllers
/// demands UIViewControllers, and the two sibling selection VCs are UIKit,
/// so matching their pattern keeps the player info panel consistent.
class PlaybackInfoViewController: UIViewController, AVPlayerViewControllerDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var info: PlaybackInfo

    init(info: PlaybackInfo) {
        self.info = info
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = CGSize(width: 700, height: 600)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Playback Info"
        view.backgroundColor = .clear

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PlaybackInfoCell")
        tableView.backgroundColor = .clear
        tableView.allowsSelection = false
        // Don't set allowsFocus = false here. On tvOS, focus IS the scroll
        // mechanism — Siri Remote swipes scroll a UITableView by moving
        // focus to off-screen cells. With focus disabled the panel is
        // permanently pinned to the top, hiding any section below the
        // ~600pt fold (Audio + Subtitle on most movies). Cells get the
        // standard tvOS focus highlight on hover, which matches Settings
        // and other system info panes — read-only rows lighting up on
        // focus is the platform convention, not menu-row behavior.

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        print("📋 PlaybackInfoViewController viewDidLoad — sections=\(info.sections.count) rows=\(info.totalRows)")
        for section in info.sections {
            print("   § \(section.title): \(section.rows.count) rows — \(section.rows.map { "\($0.label)=\($0.value)" }.joined(separator: ", "))")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()  // picks up any mid-playback mode flips
        print("📋 PlaybackInfoViewController viewWillAppear — rendering \(info.totalRows) rows across \(info.sections.count) sections")
    }

    /// Push fresh info into the pane. Called by the player when the
    /// PlaybackMode flips (e.g. failover to transcode) or on bitrate
    /// reload. Safe to call even when the view isn't loaded yet.
    func update(info: PlaybackInfo) {
        self.info = info
        if isViewLoaded {
            tableView.reloadData()
        }
    }
}

// MARK: - UITableView Delegate & DataSource

extension PlaybackInfoViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return info.sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return info.sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return info.sections[section].title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // `.value1` = left-aligned label + right-aligned detail. Matches
        // Infuse / iOS Settings-style info panels; no manual layout needed.
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "PlaybackInfoCell")
        let row = info.sections[indexPath.section].rows[indexPath.row]

        cell.textLabel?.text = row.label
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = UIFont.systemFont(ofSize: 26, weight: .regular)

        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.textColor = UIColor(white: 1.0, alpha: 0.7)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 26, weight: .medium)

        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none

        return cell
    }
}
