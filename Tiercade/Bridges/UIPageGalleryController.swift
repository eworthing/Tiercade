import Foundation

#if os(tvOS)
import UIKit

final class UIPageGalleryController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
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
		if let first = pages.first { setViewControllers([controller(for: first)], direction: .forward, animated: false) }
	}

	// MARK: Data source
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		guard let key = key(for: viewController), let idx = pages.firstIndex(of: key), idx > 0 else { return nil }
		let prev = pages[idx - 1]
		return controller(for: prev)
	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		guard let key = key(for: viewController), let idx = pages.firstIndex(of: key), idx < pages.count - 1 else { return nil }
		let next = pages[idx + 1]
		return controller(for: next)
	}

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		guard completed, let vc = viewControllers?.first, let key = key(for: vc) else { return }
		prefetch(adjacentTo: key)
		if let idx = pages.firstIndex(of: key) {
			let msg = "Image \(idx + 1) of \(pages.count)"
			UIAccessibility.post(notification: .announcement, argument: msg)
		}
	}

	// MARK: Helpers
	private func controller(for key: PageItem) -> UIViewController {
		if let c = controllers[key] { return c }
		let c = UIViewController()
		c.view.backgroundColor = .clear
		let iv = UIImageView()
		iv.contentMode = .scaleAspectFit
		iv.translatesAutoresizingMaskIntoConstraints = false
		c.view.addSubview(iv)
		NSLayoutConstraint.activate([
			iv.leadingAnchor.constraint(equalTo: c.view.leadingAnchor),
			iv.trailingAnchor.constraint(equalTo: c.view.trailingAnchor),
			iv.topAnchor.constraint(equalTo: c.view.topAnchor),
			iv.bottomAnchor.constraint(equalTo: c.view.bottomAnchor)
		])
		if let url = URL(string: key.uri) {
			URLSession.shared.dataTask(with: url) { data, _, _ in
				guard let data = data, let img = UIImage(data: data) else { return }
				DispatchQueue.main.async { iv.image = img }
			}.resume()
		}
		// a11y identifiers
		c.view.isAccessibilityElement = true
		c.view.accessibilityIdentifier = "Gallery_Page_\(key.uri)"
		controllers[key] = c
		return c
	}

	private func key(for controller: UIViewController) -> PageItem? {
		return controllers.first(where: { $0.value === controller })?.key
	}

	private func prefetch(adjacentTo key: PageItem) {
		guard let idx = pages.firstIndex(of: key) else { return }
		for off in [-1, 1] {
			let i = idx + off
			guard i >= 0 && i < pages.count else { continue }
			let neighbor = pages[i]
			if controllers[neighbor] == nil { _ = controller(for: neighbor) }
		}
	}
}

// SwiftUI wrapper for embedding
import SwiftUI
struct PageGalleryView: UIViewControllerRepresentable {
	let uris: [String]

	func makeUIViewController(context: Context) -> UIPageGalleryController {
		return UIPageGalleryController(uris: uris)
	}

	func updateUIViewController(_ uiViewController: UIPageGalleryController, context: Context) {
		uiViewController.update(uris: uris)
	}
}
#endif
