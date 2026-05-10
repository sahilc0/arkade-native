import AVFoundation
import SwiftUI

struct QRScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let onScan: (String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                QRScannerView { code in
                    onScan(code)
                    dismiss()
                }
                .ignoresSafeArea()

                ScannerOverlay(title: title)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ScannerOverlay: View {
    let title: String

    var body: some View {
        VStack {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("Align the QR code inside the frame")
                    .font(Arkade.smallFont)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.top, 24)

            Spacer()

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 240, height: 240)
                .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)

            Spacer()
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(Arkade.hPadding)
        .allowsHitTesting(false)
    }
}

private struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        didScan = false
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [session] in
                session.stopRunning()
            }
        }
    }

    private func configureCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showUnavailableMessage()
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            showUnavailableMessage()
            return
        }

        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    private func showUnavailableMessage() {
        let label = UILabel()
        label.text = "Camera unavailable"
        label.textColor = .white
        label.font = .preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else {
            return
        }

        didScan = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onScan?(value)
    }
}
