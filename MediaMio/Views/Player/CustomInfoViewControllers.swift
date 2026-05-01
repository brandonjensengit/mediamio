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
        tableView.register(Value1Cell.self, forCellReuseIdentifier: "PlaybackInfoCell")
        tableView.register(SectionHeaderHost.self, forHeaderFooterViewReuseIdentifier: "PlaybackInfoSectionHeader")
        tableView.backgroundColor = .clear
        // On tvOS, focus IS the scroll mechanism — Siri Remote swipes
        // scroll a UITableView by moving focus through its cells. Two
        // flags conspire to disable that, and BOTH must be left on:
        //   - allowsFocus (default true) — allows cells into the focus
        //     graph at all
        //   - allowsSelection (default true) — the focus engine treats
        //     unselectable cells as unfocusable, so disabling selection
        //     makes the table un-scrollable
        // We keep selection on but ignore taps in the delegate (the empty
        // didSelectRowAt is intentional). cell.selectionStyle = .none
        // suppresses the highlight flash; the focus highlight remains as
        // a "you are here" cursor for the swipe gesture, matching the
        // platform convention for read-only info panes.
        //
        // remembersLastFocusedIndexPath: when SwiftUI re-emits the panel
        // via `updateUIViewController` and we call `update(info:)`, the
        // table reloads and tvOS would otherwise reset focus to row 0 —
        // yanking the user back to the top mid-swipe. With this on, the
        // focus engine restores focus to whichever cell the user was on
        // before the reload, so a delivered-info change refresh does NOT
        // auto-scroll the panel.
        tableView.remembersLastFocusedIndexPath = true

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
    /// PlaybackMode flips (e.g. failover to transcode) or when AVPlayer's
    /// delivered-track snapshot changes. Safe to call even when the view
    /// isn't loaded yet.
    ///
    /// Reload semantics: when only row VALUES change (the common case —
    /// codec/resolution arrives a few seconds after readyToPlay), we
    /// reconfigure the existing visible cells in place rather than
    /// calling `reloadData()`. `reloadData` invalidates the focus state
    /// and would yank the user back to the top of the table mid-swipe.
    /// Falling back to `reloadData` only when the row/section count
    /// changes (rare — section count is fixed at 4, but row counts can
    /// vary as Container/File Size become available).
    func update(info: PlaybackInfo) {
        let prior = self.info
        self.info = info
        guard isViewLoaded else { return }

        let structureChanged = prior.sections.count != info.sections.count
            || zip(prior.sections, info.sections).contains { $0.0.rows.count != $0.1.rows.count }

        if structureChanged {
            tableView.reloadData()
            return
        }
        // Same shape → reconfigure the visible cells without disturbing
        // focus or scroll position. Section header pills (badge color)
        // also need a refresh; reloadSections would jump focus, so we
        // re-apply via the visible header views directly.
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            guard let cell = tableView.cellForRow(at: indexPath) else { continue }
            configure(cell: cell, at: indexPath)
        }
        for sectionIndex in 0..<info.sections.count {
            if let header = tableView.headerView(forSection: sectionIndex) as? SectionHeaderHost {
                header.apply(badge: info.sections[sectionIndex].badge,
                             title: info.sections[sectionIndex].title)
            }
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

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let model = info.sections[section]
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "PlaybackInfoSectionHeader")
            as? SectionHeaderHost
            ?? SectionHeaderHost(reuseIdentifier: "PlaybackInfoSectionHeader")
        header.apply(badge: model.badge, title: model.title)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 56
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaybackInfoCell", for: indexPath)
        configure(cell: cell, at: indexPath)
        return cell
    }

    /// Apply the row at `indexPath` to `cell`. Extracted so `update(info:)`
    /// can refresh visible cells in place without calling `reloadData`,
    /// which would reset focus.
    fileprivate func configure(cell: UITableViewCell, at indexPath: IndexPath) {
        let row = info.sections[indexPath.section].rows[indexPath.row]

        // `.value1` = left-aligned label + right-aligned detail. We keep
        // it for layout but switch the detail to an attributed string
        // when the row carries a delivered companion that disagrees
        // with source — the renderer composes "<source> → <delivered>"
        // with the delivered span colored orange. That gives a clean
        // single-line "what AVPlayer is actually decoding" diagnostic
        // without redesigning the cell layout.
        cell.textLabel?.text = row.label
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = UIFont.systemFont(ofSize: 26, weight: .regular)

        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 26, weight: .medium)
        if row.isMismatch, let delivered = row.delivered {
            cell.detailTextLabel?.attributedText = Self.mismatchAttributed(
                source: row.value,
                delivered: delivered
            )
        } else {
            cell.detailTextLabel?.attributedText = nil
            cell.detailTextLabel?.text = row.value
            cell.detailTextLabel?.textColor = UIColor(white: 1.0, alpha: 0.7)
        }

        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.selectionStyle = .none
    }

    /// Compose `"HEVC → H.264"` with three colored spans:
    /// source = 70%-white (matches the read-only field convention), arrow
    /// = 40%-white (muted separator), delivered = systemOrange (the
    /// "this is wrong" alarm color tvOS uses for warnings). Static so
    /// it's trivially testable and we don't allocate a closure per cell.
    private static func mismatchAttributed(source: String, delivered: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let baseFont = UIFont.systemFont(ofSize: 26, weight: .medium)
        result.append(NSAttributedString(string: source, attributes: [
            .font: baseFont,
            .foregroundColor: UIColor(white: 1.0, alpha: 0.7)
        ]))
        result.append(NSAttributedString(string: " → ", attributes: [
            .font: baseFont,
            .foregroundColor: UIColor(white: 1.0, alpha: 0.4)
        ]))
        result.append(NSAttributedString(string: delivered, attributes: [
            .font: baseFont,
            .foregroundColor: UIColor.systemOrange
        ]))
        return result
    }
}

// MARK: - Cell

/// `UITableViewCell.CellStyle.value1` baked into a registrable subclass.
/// `tableView.register(UITableViewCell.self, …)` gets the *default* style
/// — which has no `detailTextLabel` — so dequeued cells render only the
/// row label and the value silently vanishes. This subclass lets us use
/// the `.value1` layout (left-aligned label + right-aligned detail) AND
/// also `dequeueReusableCell` for in-place updates.
private final class Value1Cell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
    }
    required init?(coder: NSCoder) { fatalError("not used") }
}

// MARK: - Section header view

/// Reusable header with the title on the left and an optional pill on
/// the right. Green pill for direct-play / direct-stream / remux (the
/// source stream is reaching AVPlayer intact); orange pill for transcode
/// (the server replaced one or both streams with something else).
/// Falls back to a plain title row when no badge is set.
///
/// Subclasses `UITableViewHeaderFooterView` rather than a bare UIView so
/// the table can recycle these views and `apply(badge:title:)` can be
/// called from `update(info:)` to mutate a live header without
/// triggering a reload + focus reset.
final class SectionHeaderHost: UITableViewHeaderFooterView {
    private let titleLabel = UILabel()
    private let pillView = UIView()
    private let pillLabel = UILabel()
    private var pillTrailingConstraint: NSLayoutConstraint?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func setupSubviews() {
        backgroundView = UIView()  // suppress system grouped header bg
        backgroundView?.backgroundColor = .clear

        titleLabel.textColor = UIColor(white: 1.0, alpha: 0.6)
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        pillView.layer.cornerRadius = 10
        pillView.layer.cornerCurve = .continuous
        pillView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(pillView)

        pillLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pillView.addSubview(pillLabel)

        let pillTrailing = pillView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28)
        pillTrailingConstraint = pillTrailing

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            pillTrailing,
            pillView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            pillLabel.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 12),
            pillLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -12),
            pillLabel.topAnchor.constraint(equalTo: pillView.topAnchor, constant: 5),
            pillLabel.bottomAnchor.constraint(equalTo: pillView.bottomAnchor, constant: -5)
        ])
    }

    /// Apply a fresh title + badge to a recycled or live header. No
    /// reload required — call sites can mutate the badge color/visibility
    /// after the table is rendered, which is what `update(info:)` does
    /// when delivered-info changes mid-playback.
    func apply(badge: PlaybackBadge?, title: String) {
        titleLabel.text = title.uppercased()
        if let badge = badge {
            pillView.isHidden = false
            pillLabel.text = badge.rawValue
            let isHealthy = badge != .transcode
            pillView.backgroundColor = isHealthy
                ? UIColor.systemGreen.withAlphaComponent(0.18)
                : UIColor.systemOrange.withAlphaComponent(0.18)
            pillLabel.textColor = isHealthy ? UIColor.systemGreen : UIColor.systemOrange
        } else {
            pillView.isHidden = true
        }
    }
}
