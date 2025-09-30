import Foundation

#if os(tvOS)
import UIKit
import TiercadeCore
import OSLog

private let collectionTierRowLogger = Logger(
	subsystem: "Tiercade",
	category: "CollectionTierRowController"
)

private typealias CardCell = CollectionTierRowCardCell

@MainActor
final class CollectionTierRowController: UIViewController,
    UICollectionViewDelegate,
    UICollectionViewDataSourcePrefetching {
	enum Section { case main }

	private let tierName: String
	private var items: [Item] = []
	private var idToItem: [String: Item] = [:]
	private var viewModels: [TierRowViewModel] = []

	private var collectionView: UICollectionView?
	private var dataSource: UICollectionViewDiffableDataSource<Section, TierRowViewModel>?

	var onSelect: ((Item) -> Void)?
	var onPlayPause: ((Item) -> Void)?
	var selectedIds: Set<String> = [] { didSet { updateSelectionAppearance() } }
	var isMultiSelect: Bool = false
	var isPrefetchingEnabled: Bool = true {
		didSet {
			guard isViewLoaded else { return }
			collectionView?.isPrefetchingEnabled = isPrefetchingEnabled
		}
	}

	private var prefetchTasks: [IndexPath: Task<Void, Never>] = [:]

	init(tierName: String, items: [Item]) {
		self.tierName = tierName
		self.items = items
		super.init(nibName: nil, bundle: nil)
		rebuildState()
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .clear
		configureCollectionView()
		configureDataSource()
		collectionView?.isPrefetchingEnabled = isPrefetchingEnabled
		if viewModels.isEmpty { rebuildState() }
		applySnapshot(animated: false)
		setNeedsFocusUpdate()
		updateFocusIfNeeded()
	}

	func apply(items: [Item]) {
		self.items = items
		rebuildState()
		applySnapshot(animated: true)
	}

	private func rebuildState() {
		idToItem = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
		viewModels = items.enumerated().map { index, item in
			TierRowViewModel(item: item, index: index, totalCount: items.count, tierName: tierName)
		}
	}

	private func configureCollectionView() {
		let layout = UICollectionViewCompositionalLayout { _, _ -> NSCollectionLayoutSection? in
			let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(320), heightDimension: .absolute(220))
			let item = NSCollectionLayoutItem(layoutSize: itemSize)
			item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

			let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(320), heightDimension: .absolute(228))
			let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

			let section = NSCollectionLayoutSection(group: group)
			section.orthogonalScrollingBehavior = .continuous
			section.interGroupSpacing = 6
			section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
			return section
		}
		let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
		self.collectionView = collectionView
		collectionView.backgroundColor = .clear
		collectionView.translatesAutoresizingMaskIntoConstraints = false
		collectionView.delegate = self
		collectionView.prefetchDataSource = self
		collectionView.isPrefetchingEnabled = isPrefetchingEnabled
		collectionView.remembersLastFocusedIndexPath = true
		view.addSubview(collectionView)
		NSLayoutConstraint.activate([
			collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			collectionView.topAnchor.constraint(equalTo: view.topAnchor),
			collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
		])

		collectionView.register(CardCell.self, forCellWithReuseIdentifier: CardCell.reuseID)
	}

	private lazy var cardCellRegistration = UICollectionView.CellRegistration<
		CardCell,
		TierRowViewModel
	> { [weak self] cell, _, viewModel in
		guard let self else { return }
		let isSelected = selectedIds.contains(viewModel.id)
		cell.configure(with: viewModel, selected: isSelected)
		cell.onPlayPause = { [weak self] in
			guard let self, let item = self.idToItem[viewModel.id] else { return }
			self.onPlayPause?(item)
		}
	}

	private func configureDataSource() {
		guard let collectionView else { return }
		dataSource = UICollectionViewDiffableDataSource<Section, TierRowViewModel>(
			collectionView: collectionView
		) { [weak self] collectionView, indexPath, viewModel in
			guard let self else { return nil }
			return collectionView.dequeueConfiguredReusableCell(
				using: self.cardCellRegistration,
				for: indexPath,
				item: viewModel
			)
		}
	}

	private func applySnapshot(animated: Bool) {
		guard isViewLoaded, let dataSource else { return }
		var snap = NSDiffableDataSourceSnapshot<Section, TierRowViewModel>()
		snap.appendSections([.main])
		snap.appendItems(viewModels, toSection: .main)
		dataSource.apply(snap, animatingDifferences: animated)
	}

	private func updateSelectionAppearance() {
		guard let collectionView, let dataSource else { return }
		for case let cell as CardCell in collectionView.visibleCells {
			guard
				let indexPath = collectionView.indexPath(for: cell),
				let viewModel = dataSource.itemIdentifier(for: indexPath)
			else { continue }
			cell.setSelectedOverlay(visible: selectedIds.contains(viewModel.id))
		}
	}

	// MARK: - Delegate

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard
			let viewModel = dataSource?.itemIdentifier(for: indexPath),
			let item = idToItem[viewModel.id]
		else { return }
		onSelect?(item)
	}

	// MARK: - Prefetching
	func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
		guard isPrefetchingEnabled else { return }
		for indexPath in indexPaths {
			guard prefetchTasks[indexPath] == nil, indexPath.item < viewModels.count else { continue }
			let viewModel = viewModels[indexPath.item]
			guard let url = viewModel.imageURL else { continue }
			let task = Task(priority: .utility) { [weak self] in
				defer {
					Task { @MainActor [weak self] in
						self?.removePrefetchTask(for: indexPath)
					}
				}
				guard !Task.isCancelled else { return }
				await ImageLoader.shared.prefetch(url)
			}
			prefetchTasks[indexPath] = task
		}
	}

	func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
		for indexPath in indexPaths {
			prefetchTasks[indexPath]?.cancel()
			prefetchTasks[indexPath] = nil
		}
	}

	private func removePrefetchTask(for indexPath: IndexPath) {
		prefetchTasks[indexPath] = nil
	}
}

// MARK: - CollectionTierRowCardCell

final class CollectionTierRowCardCell: UICollectionViewCell {
	static let reuseID = "CardCell"
	private let imageView = UIImageView()
	private let label = UILabel()
	private let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
	private var imageTask: Task<Void, Never>?
	var onPlayPause: (() -> Void)?

	override init(frame: CGRect) {
		super.init(frame: frame)
		configureAppearance()
		configureLayout()
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	override func prepareForReuse() {
		super.prepareForReuse()
		imageTask?.cancel()
		imageTask = nil
		imageView.image = nil
		label.text = nil
	}

	func configure(with viewModel: TierRowViewModel, selected: Bool, loader: ImageLoader = .shared) {
		label.text = viewModel.displayName
		setSelectedOverlay(visible: selected)
		isAccessibilityElement = true
		accessibilityIdentifier = viewModel.accessibilityIdentifier
		accessibilityLabel = viewModel.accessibilityLabel
		imageTask?.cancel()
		imageTask = nil
		imageView.image = nil
		guard let url = viewModel.imageURL else { return }
		imageTask = Task { [weak self] in
			guard let self else { return }
			if let cached = await loader.cachedImage(for: url) {
				await MainActor.run { self.imageView.image = cached }
				return
			}
			do {
				let image = try await loader.image(for: url)
				try Task.checkCancellation()
				await MainActor.run { self.imageView.image = image }
			} catch is CancellationError {
				// Ignore cancellations
			} catch {
				let id = viewModel.id
				let description = error.localizedDescription
				collectionTierRowLogger.error(
					"Image load failed for id=\(id, privacy: .public): \(description, privacy: .public)"
				)
			}
		}
	}

	func setSelectedOverlay(visible: Bool) { checkmark.isHidden = !visible }

	// Focus animations
	override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
		super.didUpdateFocus(in: context, with: coordinator)
		let focused = (context.nextFocusedView == self)
		coordinator.addCoordinatedAnimations({
			self.transform = focused ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
			self.layer.shadowColor = UIColor.black.cgColor
			self.layer.shadowOpacity = focused ? 0.4 : 0.12
			self.layer.shadowRadius = focused ? 24 : 8
			self.layer.shadowOffset = CGSize(width: 0, height: focused ? 12 : 4)
		}, completion: nil)
	}

	// Handle Play/Pause
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		if presses.contains(where: { $0.type == .playPause }) {
			onPlayPause?()
		} else {
			super.pressesBegan(presses, with: event)
		}
	}

	private func configureAppearance() {
		contentView.layer.cornerRadius = 16
		contentView.layer.masksToBounds = true
		let scale = max(1, traitCollection.displayScale)
		contentView.layer.borderWidth = 1 / scale
		contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor

		imageView.contentMode = .scaleAspectFill
		imageView.clipsToBounds = true
		imageView.backgroundColor = UIColor.darkGray
		label.font = .systemFont(ofSize: 20, weight: .semibold)
		label.textColor = .white
		label.numberOfLines = 1
		label.textAlignment = .center
		label.backgroundColor = UIColor.black.withAlphaComponent(0.35)

		checkmark.tintColor = .systemBlue
		checkmark.isHidden = true
		checkmark.translatesAutoresizingMaskIntoConstraints = false
	}

	private func configureLayout() {
		let stack = UIStackView(arrangedSubviews: [imageView])
		stack.axis = .vertical
		stack.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
			stack.topAnchor.constraint(equalTo: contentView.topAnchor),
			stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
		])

		imageView.addSubview(label)
		label.translatesAutoresizingMaskIntoConstraints = false
		NSLayoutConstraint.activate([
			label.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 8),
			label.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -8),
			label.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -8)
		])

		contentView.addSubview(checkmark)
		NSLayoutConstraint.activate([
			checkmark.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
			checkmark.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
		])
	}
}

#endif
