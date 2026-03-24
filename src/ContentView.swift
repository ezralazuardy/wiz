import SwiftUI
import AVFoundation

class SoundPlayer: ObservableObject {
    var player: AVAudioPlayer?

    func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
            print("Sound file '\(name).wav' not found.")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 1
            player?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var viewModel: BulbService
    @StateObject private var soundPlayer = SoundPlayer()
    @State private var isLightOn = false
    @State private var scale: CGFloat = 0.95

    init() {
        _viewModel = StateObject(wrappedValue: BulbService())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack {
                Spacer().frame(height: 50)

                Text("Philips Wiz")
                    .font(.custom("Avenir-Heavy", size: 32))
                    .foregroundColor(.white)
                    .padding(.bottom, 40)

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.3)) {
                        isLightOn.toggle()
                        scale = 1.1
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scale = 0.95
                        }
                    }

                    soundPlayer.play(isLightOn ? "on" : "off")

                    DispatchQueue.global(qos: .userInitiated).async {
                        isLightOn ? viewModel.lightOn() : viewModel.lightOff()
                    }
                }) {
                    HStack {
                        Image(systemName: isLightOn ? "lightbulb.fill" : "lightbulb.slash")
                        Text(isLightOn ? "Turn Off" : "Turn On")
                    }
                    .font(.custom("Avenir-Heavy", size: 17))
                    .frame(width: 160, height: 55)
                    .background(isLightOn ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(28)
                    .scaleEffect(scale)
                    .shadow(
                        color: colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.4),
                        radius: 8, x: 0, y: 0
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 35)

                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(viewModel.boxColor)
                            .frame(width: 14, height: 14)
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            .frame(width: 18, height: 18)
                            .blur(radius: 2)
                    }

                    Button(action: {
                        viewModel.connectBulb()
                    }) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .padding(5)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .shadow(
                                color: colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.3),
                                radius: 3, x: 0, y: 0
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                if !viewModel.statusMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.boxColor == .green ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(viewModel.boxColor == .green ? .green : .red)
                        Text(viewModel.statusMessage)
                            .font(.custom("Avenir", size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 30)
        }
        .task {
            print("Connecting bulb on view appear")
            viewModel.connectBulb()
        }
        .onChange(of: viewModel.statusMessage) {
            guard !viewModel.statusMessage.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    viewModel.statusMessage = ""
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
