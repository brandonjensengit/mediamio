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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Video Quality"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "BitrateCell")
        tableView.backgroundColor = .clear

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
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
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return bitrateOptions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BitrateCell", for: indexPath)
        let option = bitrateOptions[indexPath.row]

        cell.textLabel?.text = option.label
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .clear

        // Show checkmark for selected option
        if option.value == settingsManager.maxBitrate {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Audio Quality"

        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AudioCell")
        tableView.backgroundColor = .clear

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
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
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return audioQualityOptions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AudioCell", for: indexPath)
        let option = audioQualityOptions[indexPath.row]

        cell.textLabel?.text = option.label
        cell.textLabel?.textColor = .white
        cell.backgroundColor = .clear

        // Show checkmark for selected option
        if option.value == settingsManager.audioQuality {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }

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
