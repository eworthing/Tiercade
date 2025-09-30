import Foundation

#if os(tvOS)
import UIKit

final class UIPageGalleryController: UIPageViewController,
	UIPageViewControllerDataSource,
	UIPageViewControllerDelegate {
	struct PageItem: Hashable { let uri: String }

	private var pages: [PageItem] = []
	private var controllers: [PageItem: UIViewController] = [:]

	init(uris: [String]) {
		super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
		self.dataSource = self
		self.delegate = self
		self.pages = uris.compactMap { PageItem(uri: $0) }
		if let first = pages.first {
			setViewControllers([controller(for: first)], direction: .forward, animated: false)
			prefetch(adjacentTo: first)
		}
	}

	required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

	func update(uris: [String]) {
		self.pages = uris.compactMap { PageItem(uri: $0) }
		if let first = pages.first {
			setViewControllers(
				[controller(for: first)],
				direction: .forward,
				animated: false
			)
		}
	}

	// MARK: Data source
	func pageViewController(
		_ pageViewController: UIPageViewController,
		viewControllerBefore viewController: UIViewController
	) -> UIViewController? {
		guard
			let key = key(for: viewController),
			let idx = pages.firstIndex(of: key),
			idx > 0
		else { return nil }
		let prev = pages[idx - 1]
		return controller(for: prev)
	}

	func pageViewController(
		_ pageViewController: UIPageViewController,
		viewControllerAfter viewController: UIViewController
	) -> UIViewController? {
		guard
			let key = key(for: viewController),
			let idx = pages.firstIndex(of: key),
			idx < pages.count - 1
		else { return nil }
		let next = pages[idx + 1]
		return controller(for: next)
	}

	func pageViewController(
		_ pageViewController: UIPageViewController,
		didFinishAnimating finished: Bool,
		previousViewControllers: [UIViewController],
		transitionCompleted completed: Bool
	) {
		guard completed, let vc = viewControllers?.first, let key = key(for: vc) else { return }
		prefetch(adjacentTo: key)
		if let idx = pages.firstIndex(of: key) {
			let msg = "Image \(idx + 1) of \(pages.count)"
			UIAccessibility.post(notification: .announcement, argument: msg)
		}
	}

	// MARK: Helpers
	private func controller(for key: PageItem) -> UIViewController {
		if let existing = controllers[key] { return existing }
		let controller = UIViewController()
		controller.view.backgroundColor = .clear
		let imageView = UIImageView()
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false
		controller.view.addSubview(imageView)
		NSLayoutConstraint.activate([
			imageView.leadingAnchor.constraint(equalTo: controller.view.leadingAnchor),
			imageView.trailingAnchor.constraint(equalTo: controller.view.trailingAnchor),
			imageView.topAnchor.constraint(equalTo: controller.view.topAnchor),
			imageView.bottomAnchor.constraint(equalTo: controller.view.bottomAnchor)
		])
		if let url = URL(string: key.uri) {
			URLSession.shared.dataTask(with: url) { data, _, _ in
				guard let data, let image = UIImage(data: data) else { return }
				DispatchQueue.main.async {
					imageView.image = image
				}
			}.resume()
		}
		// a11y identifiers
		controller.view.isAccessibilityElement = true
		controller.view.accessibilityIdentifier = "Gallery_Page_\(key.uri)"
		controllers[key] = controller
		return controller
	}

	private func key(for controller: UIViewController) -> PageItem? {
		return controllers.first(where: { $0.value === controller })?.key
	}

	private func prefetch(adjacentTo key: PageItem) {
		guard let idx = pages.firstIndex(of: key) else { return }
		for offset in [-1, 1] {
			let neighborIndex = idx + offset
			guard neighborIndex >= 0 && neighborIndex < pages.count else { continue }
			let neighbor = pages[neighborIndex]
			if controllers[neighbor] == nil {
				_ = controller(for: neighbor)
			}
		}
	}
}

// SwiftUI wrapper for embedding
import SwiftUI
struct PageGalleryView: UIViewControllerRepresentable {
	let uris: [String]

	func makeUIViewController(context: Context) -> UIPageGalleryController {
		UIPageGalleryController(uris: uris)
	}

	func updateUIViewController(_ uiViewController: UIPageGalleryController, context: Context) {
		uiViewController.update(uris: uris)
	}
}
#endif
