import SwiftUI
import AVFoundation
import AudioToolbox

// MARK: - SwiftUI wrapper

struct TicketQRCameraView: View {
    var onDetected: ([String]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var permissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if permissionStatus == .authorized {
                CameraPreviewRepresentable(onDetected: { codes in
                    onDetected(codes)
                    dismiss()
                })
                .ignoresSafeArea()
                scanOverlay
            } else if permissionStatus == .denied || permissionStatus == .restricted {
                permissionDeniedView
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if permissionStatus == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { _ in
                    DispatchQueue.main.async {
                        permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
                    }
                }
            }
        }
    }

    // MARK: - Overlay

    private var scanOverlay: some View {
        VStack(spacing: 0) {
            // Title bar
            ZStack {
                LinearGradient(colors: [.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 100)
                    .ignoresSafeArea(edges: .top)

                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .buttonStyle(ScalePressStyle())
                    Spacer()
                    Text("QRスキャン")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
            }

            Spacer()

            // Viewfinder
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                    .frame(width: 260, height: 260)

                cornerMarkers
            }

            Text("馬券のQRコードを枠内に合わせてください\n2つのQRを順番にスキャンできます")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var cornerMarkers: some View {
        let size: CGFloat = 260
        let arm: CGFloat = 28
        let thick: CGFloat = 3
        return ZStack {
            cornerL(flipH: false, flipV: false, arm: arm, thick: thick, size: size)
            cornerL(flipH: true,  flipV: false, arm: arm, thick: thick, size: size)
            cornerL(flipH: false, flipV: true,  arm: arm, thick: thick, size: size)
            cornerL(flipH: true,  flipV: true,  arm: arm, thick: thick, size: size)
        }
        .frame(width: size, height: size)
    }

    private func cornerL(flipH: Bool, flipV: Bool, arm: CGFloat, thick: CGFloat, size: CGFloat) -> some View {
        let hMult: CGFloat = flipH ? -1 : 1
        let vMult: CGFloat = flipV ? -1 : 1
        return Path { path in
            let cx: CGFloat = flipH ? size : 0
            let cy: CGFloat = flipV ? size : 0
            path.move(to: CGPoint(x: cx, y: cy + vMult * arm))
            path.addLine(to: CGPoint(x: cx, y: cy))
            path.addLine(to: CGPoint(x: cx + hMult * arm, y: cy))
        }
        .stroke(SplatTheme.cyan, style: StrokeStyle(lineWidth: thick, lineCap: .round))
    }

    // MARK: - Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 52))
                .foregroundColor(.white.opacity(0.25))
            Text("カメラへのアクセスが\n許可されていません")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("設定 > Pakapick > カメラ\nをオンにしてください")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
            Button { dismiss() } label: {
                Text("閉じる")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(.white.opacity(0.1))
                    .cornerRadius(30)
            }
            Spacer()
        }
    }
}

// MARK: - UIKit bridge

struct CameraPreviewRepresentable: UIViewControllerRepresentable {
    var onDetected: ([String]) -> Void

    func makeUIViewController(context: Context) -> QRCameraViewController {
        QRCameraViewController(onDetected: onDetected)
    }

    func updateUIViewController(_ uiViewController: QRCameraViewController, context: Context) {}
}

final class QRCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let onDetected: ([String]) -> Void
    private var session: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasDetected = false

    init(onDetected: @escaping ([String]) -> Void) {
        self.onDetected = onDetected
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session?.stopRunning()
    }

    private func setupSession() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr, .code128]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)

        self.previewLayer = preview
        self.session = session

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session?.startRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasDetected else { return }
        let codes = metadataObjects
            .compactMap { $0 as? AVMetadataMachineReadableCodeObject }
            .compactMap { $0.stringValue }
        guard !codes.isEmpty else { return }
        hasDetected = true
        session?.stopRunning()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        onDetected(codes)
    }
}
