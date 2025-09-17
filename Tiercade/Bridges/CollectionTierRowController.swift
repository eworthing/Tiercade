import Foundation

#if os(tvOS)
import UIKit
import TiercadeCore

final class CollectionTierRowController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSourcePrefetching {
	enum Section { case main }

	private let tierName: String
	private var items: [Item] = []
	private var idToItem: [String: Item] = [:]

	private var collectionView: UICollectionView!
	private var dataSource: UICollectionViewDiffableDataSource<Section, String>!

	var onSelect: ((Item) -> Void)?
	var onPlayPause: ((Item) -> Void)?
	var selectedIds: Set<String> = [] { didSet { updateSelectionAppearance() } }
	var isMultiSelect: Bool = false
	var isPrefetchingEnabled: Bool = true {
		didSet { collectionView.isPrefetchingEnabled = isPrefetchingEnabled }
	}

	// Simple image cache
	private static let imageCache = NSCache<NSString, UIImage>()
	private var inflightTasks: [IndexPath: URLSessionDataTask] = [:]

	init(tierName: String, items: [Item]) {
		self.tierName = tierName
		self.items = items
		super.init(nibName: nil, bundle: nil)
		rebuildMap()
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .clear
		configureCollectionView()
		configureDataSource()
		applySnapshot(animated: false)
		setNeedsFocusUpdate()
		updateFocusIfNeeded()
	}

	func apply(items: [Item]) {
		self.items = items
		rebuildMap()
		applySnapshot(animated: true)
	}

	private func rebuildMap() { idToItem = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) }) }

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
		collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
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

	private func configureDataSource() {
		dataSource = UICollectionViewDiffableDataSource<Section, String>(collectionView: collectionView) { [weak self] cv, indexPath, itemID in
			guard let self = self else { return nil }
			let cell = cv.dequeueReusableCell(withReuseIdentifier: CardCell.reuseID, for: indexPath) as! CardCell
			if let item = self.idToItem[itemID] {
				let selected = self.selectedIds.contains(item.id)
				cell.configure(with: item, selected: selected)
				// Accessibility identifiers for UITests
				cell.accessibilityIdentifier = "Card_\(self.tierName)_\(indexPath.item)"
				// Accessibility label includes item name and position in tier
				let position = indexPath.item + 1
				let total = self.items.count
				let itemName = item.name ?? item.id
				cell.accessibilityLabel = "\(itemName), position \(position) of \(total) in \(self.tierName) tier"
				cell.onPlayPause = { [weak self] in
					guard let self = self else { return }
					self.onPlayPause?(item)
				}
			}
			return cell
		}
	}

	private func applySnapshot(animated: Bool) {
		var snap = NSDiffableDataSourceSnapshot<Section, String>()
		snap.appendSections([.main])
		snap.appendItems(items.map { $0.id }, toSection: .main)
		dataSource.apply(snap, animatingDifferences: animated)
	}

	private func updateSelectionAppearance() {
		for case let cell as CardCell in collectionView.visibleCells {
			if let indexPath = collectionView.indexPath(for: cell), indexPath.item < items.count {
				let item = items[indexPath.item]
				cell.setSelectedOverlay(visible: selectedIds.contains(item.id))
			}
		}
	}

	// MARK: - Delegate

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		guard indexPath.item < items.count else { return }
		onSelect?(items[indexPath.item])
	}

	// MARK: - Prefetching
	func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
		guard isPrefetchingEnabled else { return }
		for indexPath in indexPaths {
			guard indexPath.item < items.count, inflightTasks[indexPath] == nil else { continue }
			if let url = urlForItem(at: indexPath) {
				if Self.imageCache.object(forKey: url.absoluteString as NSString) != nil { continue }
				let task = URLSession.shared.dataTask(with: url) { data, _, _ in
					defer { self.inflightTasks[indexPath] = nil }
					guard let data = data, let img = UIImage(data: data) else { return }
					Self.imageCache.setObject(img, forKey: url.absoluteString as NSString)
				}
				inflightTasks[indexPath] = task
				task.resume()
			}
		}
	}

	func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
		for indexPath in indexPaths {
			inflightTasks[indexPath]?.cancel()
			inflightTasks[indexPath] = nil
		}
	}

	private func urlForItem(at indexPath: IndexPath) -> URL? {
		guard indexPath.item < items.count else { return nil }
		let item = items[indexPath.item]
		if let s = item.imageUrl ?? item.videoUrl, let url = URL(string: s) { return url }
		return nil
	}

	// MARK: - Cell
	final class CardCell: UICollectionViewCell {
		static let reuseID = "CardCell"
		private let imageView = UIImageView()
		private let label = UILabel()
		private let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
		var onPlayPause: (() -> Void)?

		override init(frame: CGRect) {
			super.init(frame: frame)
			contentView.layer.cornerRadius = 16
			contentView.layer.masksToBounds = true
			contentView.layer.borderWidth = 1 / UIScreen.main.scale
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

		required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

		override func prepareForReuse() {
			super.prepareForReuse()
			imageView.image = nil
			label.text = nil
		}

		func configure(with item: Item, selected: Bool) {
			label.text = item.name ?? item.id
			if let s = item.imageUrl ?? item.videoUrl, let url = URL(string: s) {
				if let img = CollectionTierRowController.imageCache.object(forKey: url.absoluteString as NSString) {
					self.imageView.image = img
				} else {
					URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
						guard let self = self, let data = data, let img = UIImage(data: data) else { return }
						CollectionTierRowController.imageCache.setObject(img, forKey: url.absoluteString as NSString)
						DispatchQueue.main.async { self.imageView.image = img }
					}.resume()
				}
			}
			setSelectedOverlay(visible: selected)
			isAccessibilityElement = true
			accessibilityLabel = (item.name ?? item.id)
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
	}
}
#endif
