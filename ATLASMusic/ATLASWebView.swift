import SwiftUI
import WebKit

struct ATLASWebView: UIViewRepresentable {
    private let atlasURL = URL(
        string: "https://drakeroche4-star.github.io/atlas-music/"
    )!

    func makeCoordinator() -> Coordinator {
        Coordinator(atlasURL: atlasURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.allowsBackForwardNavigationGestures = true

        context.coordinator.webView = webView

        let request = URLRequest(
            url: atlasURL,
            cachePolicy: .reloadRevalidatingCacheData,
            timeoutInterval: 30
        )

        webView.load(request)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Keep the existing page alive so playback and local web data survive
        // normal SwiftUI updates.
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let atlasURL: URL
        weak var webView: WKWebView?

        init(atlasURL: URL) {
            self.atlasURL = atlasURL
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Keep ATLAS Music and its GitHub Pages resources inside the app.
            if url.host == atlasURL.host || url.scheme == "blob" || url.scheme == "data" {
                decisionHandler(.allow)
                return
            }

            // Allow HTTPS resources requested by the page itself.
            if navigationAction.targetFrame == nil {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            print("ATLAS Music navigation error: \(error)")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            print("ATLAS Music provisional navigation error: \(error)")
        }
    }
}
