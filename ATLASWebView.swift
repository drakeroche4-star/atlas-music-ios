import SwiftUI
import WebKit
import UniformTypeIdentifiers
import UIKit

struct ATLASWebViewControllerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ATLASWebViewController {
        ATLASWebViewController()
    }

    func updateUIViewController(
        _ uiViewController: ATLASWebViewController,
        context: Context
    ) {
        // Keep the current page alive during normal SwiftUI updates.
    }
}

final class ATLASWebViewController:
    UIViewController,
    WKNavigationDelegate,
    WKUIDelegate,
    WKScriptMessageHandler,
    UIDocumentPickerDelegate {

    private let atlasURL = URL(
        string: "https://drakeroche4-star.github.io/atlas-music/"
    )!

    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        let contentController = WKUserContentController()
        contentController.add(
            self,
            name: "atlasNativeRestore"
        )

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController = contentController

        let pagePreferences = WKWebpagePreferences()
        pagePreferences.allowsContentJavaScript = true
        pagePreferences.preferredContentMode = .mobile
        configuration.defaultWebpagePreferences = pagePreferences

        webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // The website already handles iPhone safe-area CSS itself.
        // Do not let UIKit add a second set of insets.
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Keep the page sized like an iPhone web app instead of a desktop page.
        webView.customUserAgent =
            "ATLASMusic/2.0 Mobile iPhone AppleWebKit Safari"

        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let request = URLRequest(
            url: atlasURL,
            cachePolicy: .reloadRevalidatingCacheData,
            timeoutInterval: 30
        )

        webView.load(request)
    }

    deinit {
        webView?
            .configuration
            .userContentController
            .removeScriptMessageHandler(
                forName: "atlasNativeRestore"
            )
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        false
    }

    // MARK: - Navigation

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""

        if (
            url.host == atlasURL.host ||
            scheme == "blob" ||
            scheme == "data" ||
            scheme == "about"
        ) {
            decisionHandler(.allow)
            return
        }

        // Let page resources load normally. Only kick genuine new-window
        // navigations out to the system browser.
        if navigationAction.targetFrame == nil {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        installNativeBackupBridge()
    }

    // MARK: - Native backup restore bridge

    private func installNativeBackupBridge() {
        let script = #"""
        (() => {
          const attach = () => {
            const button = document.getElementById("restoreBackupButton");

            if (!button || button.dataset.atlasNativeRestore === "1") {
              return;
            }

            button.dataset.atlasNativeRestore = "1";

            button.addEventListener(
              "click",
              (event) => {
                if (
                  window.webkit &&
                  window.webkit.messageHandlers &&
                  window.webkit.messageHandlers.atlasNativeRestore
                ) {
                  event.preventDefault();
                  event.stopImmediatePropagation();

                  window.webkit.messageHandlers
                    .atlasNativeRestore
                    .postMessage({ action: "chooseBackup" });
                }
              },
              true
            );
          };

          attach();

          const observer = new MutationObserver(attach);
          observer.observe(document.documentElement, {
            childList: true,
            subtree: true
          });

          window.__atlasRestoreBackupTextFromNative = async (
            jsonText,
            filename
          ) => {
            try {
              const file = new File(
                [jsonText],
                filename || "ATLAS-Music-Backup.atlasmusic",
                { type: "application/json" }
              );

              if (typeof restoreLibraryBackup !== "function") {
                throw new Error(
                  "ATLAS restoreLibraryBackup() is not available."
                );
              }

              await restoreLibraryBackup(file);
            } catch (error) {
              console.error("Native ATLAS restore failed:", error);
              alert(
                "ATLAS Music could not restore that backup. " +
                (error && error.message ? error.message : "")
              );
            }
          };
        })();
        """#

        webView.evaluateJavaScript(script) {
            _, error in

            if let error {
                print(
                    "ATLAS native restore bridge error: \(error)"
                )
            }
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "atlasNativeRestore" else {
            return
        }

        presentBackupPicker()
    }

    private func presentBackupPicker() {
        var contentTypes: [UTType] = [.json, .data]

        if let atlasType = UTType(
            filenameExtension: "atlasmusic"
        ) {
            contentTypes.insert(atlasType, at: 0)
        }

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: true
        )

        picker.delegate = self
        picker.allowsMultipleSelection = false

        present(
            picker,
            animated: true
        )
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else {
            return
        }

        do {
            let data = try Data(contentsOf: url)

            guard let text = String(
                data: data,
                encoding: .utf8
            ) else {
                throw NSError(
                    domain: "ATLASMusic",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "The selected backup is not UTF-8 JSON."
                    ]
                )
            }

            let filename =
                url.lastPathComponent.isEmpty
                    ? "ATLAS-Music-Backup.atlasmusic"
                    : url.lastPathComponent

            sendBackupToWebApp(
                text: text,
                filename: filename
            )
        } catch {
            showRestoreError(error.localizedDescription)
        }
    }

    private func sendBackupToWebApp(
        text: String,
        filename: String
    ) {
        guard
            let textData = try? JSONSerialization.data(
                withJSONObject: [text]
            ),
            let textJSON = String(
                data: textData,
                encoding: .utf8
            ),
            let filenameData = try? JSONSerialization.data(
                withJSONObject: [filename]
            ),
            let filenameJSON = String(
                data: filenameData,
                encoding: .utf8
            )
        else {
            showRestoreError(
                "Could not prepare the backup for ATLAS Music."
            )
            return
        }

        // JSONSerialization of a one-element array gives us a safely quoted
        // JSON string after stripping [ ].
        let quotedText = String(
            textJSON.dropFirst().dropLast()
        )

        let quotedFilename = String(
            filenameJSON.dropFirst().dropLast()
        )

        let script = """
        window.__atlasRestoreBackupTextFromNative(
          \(quotedText),
          \(quotedFilename)
        );
        """

        webView.evaluateJavaScript(script) {
            _, error in

            if let error {
                self.showRestoreError(
                    error.localizedDescription
                )
            }
        }
    }

    private func showRestoreError(_ message: String) {
        let alert = UIAlertController(
            title: "ATLAS Music",
            message: "Backup restore failed.\n\n\(message)",
            preferredStyle: .alert
        )

        alert.addAction(
            UIAlertAction(
                title: "OK",
                style: .default
            )
        )

        present(
            alert,
            animated: true
        )
    }
}
