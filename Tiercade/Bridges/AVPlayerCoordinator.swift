import Foundation

#if os(tvOS)
import AVKit
import SwiftUI

final class AVPlayerCoordinator: NSObject {
	@MainActor
	func present(url: URL, from presenter: UIViewController) {
		let player = AVPlayer(url: url)
		let vc = AVPlayerViewController()
		vc.player = player
		vc.modalPresentationStyle = .fullScreen
		presenter.present(vc, animated: true) {
			player.play()
		}
	}
}

struct AVPlayerPresenter: UIViewControllerRepresentable {
	let url: URL
	@Binding var isPresented: Bool

	func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

	func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
		guard isPresented else { return }
		isPresented = false
		let coord = AVPlayerCoordinator()
		coord.present(url: url, from: uiViewController)
	}
}
#endif
