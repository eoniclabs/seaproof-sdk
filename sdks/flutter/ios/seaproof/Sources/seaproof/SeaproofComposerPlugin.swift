import Flutter
import UIKit
import UniformTypeIdentifiers

public final class SeaproofComposerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        registrar.register(ComposerFactory(messenger: registrar.messenger()), withId: "io.seaproof/composer")
    }
}

private final class ComposerFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(withFrame frame: CGRect, viewIdentifier id: Int64, arguments args: Any?) -> FlutterPlatformView {
        ComposerView(frame: frame, id: id, settings: args as? [String: Any] ?? [:], messenger: messenger)
    }
}

private final class ComposerView: NSObject, FlutterPlatformView, UITextViewDelegate, UITextPasteDelegate {
    let input: ComposerTextView
    let channel: FlutterMethodChannel

    init(frame: CGRect, id: Int64, settings: [String: Any], messenger: FlutterBinaryMessenger) {
        input = ComposerTextView(frame: frame, textContainer: nil)
        channel = FlutterMethodChannel(name: "io.seaproof/composer/\(id)", binaryMessenger: messenger)
        super.init()
        input.delegate = self
        input.pasteDelegate = self
        input.onPasteImage = { [weak self] provider in
            self?.attachImage(from: provider)
        }
        input.configure(settings)
        input.setDraft(settings["text"] as? String ?? "")
        channel.setMethodCallHandler { [weak self] call, result in
            guard let input = self?.input else {
                result(nil)
                return
            }
            switch call.method {
            case "blur":
                input.resignFirstResponder()
            case "configure":
                input.configure(call.arguments as? [String: Any] ?? [:])
            case "setText":
                input.setDraft(call.arguments as? String ?? "")
            default:
                result(FlutterMethodNotImplemented)
                return
            }
            result(nil)
        }
    }

    deinit {
        channel.setMethodCallHandler(nil)
    }

    func view() -> UIView { input }

    func textViewDidBeginEditing(_ textView: UITextView) {
        channel.invokeMethod("focus", arguments: nil)
    }

    func textViewDidChange(_ textView: UITextView) {
        input.updatePlaceholder()
        channel.invokeMethod("edit", arguments: textView.text)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let current = textView.text, let range = Range(range, in: current) else { return true }
        return current.replacingCharacters(in: range, with: text).count <= input.maxLength
    }

    func textPasteConfigurationSupporting(
        _ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, transform item: UITextPasteItem
    ) {
        guard ComposerTextView.isImageProvider(item.itemProvider) else {
            item.setDefaultResult()
            return
        }
        attachImage(from: item.itemProvider) { item.setNoResult() }
    }

    private func attachImage(from provider: NSItemProvider, finished: (() -> Void)? = nil) {
        provider.loadObject(ofClass: UIImage.self as NSItemProviderReading.Type) { [weak self] object, _ in
            let png = (object as? UIImage)?.pngData()
            DispatchQueue.main.async {
                finished?()
                let attachment = png.flatMap { $0.count <= 10 * 1024 * 1024 ? FlutterStandardTypedData(bytes: $0) : nil }
                ComposerTextView.logPaste(attachment == nil ? "image load failed" : "image attached")
                self?.channel.invokeMethod("pasteImage", arguments: attachment)
            }
        }
    }
}

private final class ComposerTextView: UITextView {
    private let placeholder = UILabel()
    private static let imageType = "public.image"
    private static let pasteDiagnostics = ProcessInfo.processInfo.environment["SEAPROOF_PASTE_DIAGNOSTICS"] == "1"
    var onPasteImage: ((NSItemProvider) -> Void)?
    var maxLength = 10_000

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        backgroundColor = .clear
        autocapitalizationType = .sentences
        textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        self.textContainer.lineFragmentPadding = 0
        placeholder.isAccessibilityElement = false
        placeholder.isUserInteractionEnabled = false
        addSubview(placeholder)
        pasteConfiguration = UIPasteConfiguration(acceptableTypeIdentifiers:
            NSString.readableTypeIdentifiersForItemProvider + UIImage.readableTypeIdentifiersForItemProvider + [Self.imageType]
        )
        if #available(iOS 18.0, *) {
            supportsAdaptiveImageGlyph = false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ settings: [String: Any]) {
        maxLength = settings["maxLength"] as? Int ?? 10_000
        isEditable = settings["enabled"] as? Bool ?? true
        let hint = settings["hint"] as? String
        placeholder.text = hint
        accessibilityLabel = hint
        let font = UIFont.systemFont(ofSize: (settings["fontSize"] as? NSNumber)?.doubleValue ?? 16)
        self.font = font
        placeholder.font = font
        textColor = color(settings["foreground"])
        tintColor = color(settings["accent"])
        placeholder.textColor = color(settings["secondary"])
        let rtl = settings["rtl"] as? Bool == true
        textAlignment = rtl ? .right : .left
        placeholder.textAlignment = textAlignment
        keyboardAppearance = settings["dark"] as? Bool == true ? .dark : .light
        setNeedsLayout()
    }

    private func color(_ value: Any?) -> UIColor? {
        guard let argb = (value as? NSNumber)?.uint32Value else { return nil }
        return UIColor(
            red: CGFloat((argb >> 16) & 255) / 255,
            green: CGFloat((argb >> 8) & 255) / 255,
            blue: CGFloat(argb & 255) / 255,
            alpha: CGFloat(argb >> 24) / 255
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let insets = textContainerInset
        placeholder.frame = CGRect(
            x: insets.left,
            y: insets.top,
            width: max(0, bounds.width - insets.left - insets.right),
            height: font?.lineHeight ?? 20
        )
    }

    func setDraft(_ value: String) {
        if text != value { text = value }
        updatePlaceholder()
    }

    func updatePlaceholder() {
        placeholder.isHidden = !text.isEmpty
    }

    static func isImageProvider(_ provider: NSItemProvider) -> Bool {
        provider.hasItemConformingToTypeIdentifier(imageType) || provider.canLoadObject(ofClass: UIImage.self)
    }

    static func logPaste(_ message: @autoclosure () -> String) {
        guard pasteDiagnostics else { return }
        FileHandle.standardError.write(Data("Seaproof paste: \(message())\n".utf8))
    }

    private func hasImage(_ pasteboard: UIPasteboard) -> Bool {
        if pasteboard.hasImages || pasteboard.contains(pasteboardTypes: [Self.imageType]) { return true }
        if #available(iOS 14.0, *) {
            return pasteboard.types.contains { UTType($0)?.conforms(to: .image) == true }
        }
        return false
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let allowed = super.canPerformAction(action, withSender: sender)
        guard action == #selector(paste(_:)), isEditable else { return allowed }
        let pasteboard = UIPasteboard.general
        let image = hasImage(pasteboard)
        Self.logPaste("menu system=\(allowed) image=\(image) types=\(pasteboard.types.joined(separator: ","))")
        return allowed || image
    }

    override func paste(_ sender: Any?) {
        let pasteboard = UIPasteboard.general
        guard hasImage(pasteboard), let provider = pasteboard.itemProviders.first(where: Self.isImageProvider) else {
            super.paste(sender)
            return
        }
        onPasteImage?(provider)
    }
}
