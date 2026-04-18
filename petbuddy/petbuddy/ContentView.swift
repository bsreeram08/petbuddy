import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var runtime: PetBuddyRuntime
    @State private var messageSender: String = "friend"
    @State private var messageText: String = "Welcome back!"
    @State private var selectedPlatform: String = "Slack"

    var body: some View {
        VStack(spacing: 16) {
            header

            if runtime.isReady {
                petCanvas
            } else {
                VStack(spacing: 12) {
                    Text("Could not load pet pack")
                        .font(.headline)
                    if let err = runtime.lastError {
                        Text(err)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    Text("For app builds, `Goldie.petpack` should be in the app bundle resources (`Contents/Resources/Goldie.petpack`). For source builds, keep it at `petbuddy/Pets/Goldie.petpack`.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 260)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 14))
            }

            controlPanel
            eventLog
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(minWidth: 620, minHeight: 760)
        .navigationTitle("PetBuddy")
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PetBuddy")
                    .font(.largeTitle.bold())
                if let pack = runtime.pack {
                    Text("Pack: \(pack.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No pet loaded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StateChip(state: runtime.state)

            VStack(alignment: .trailing, spacing: 6) {
                Text("DND")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("", isOn: Binding(
                    get: { runtime.isDND },
                    set: { _ in runtime.toggleDND() }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
    }

    private var petCanvas: some View {
        VStack(spacing: 8) {
            Text("Pet area")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.gray.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.secondary.opacity(0.5), lineWidth: 1)
                    )

                if let frameImage = runtime.petImage {
                    SpriteViewContainer(
                        image: Image(nsImage: frameImage),
                        frameSize: runtime.currentFrameSize,
                        position: runtime.petPosition,
                        state: runtime.state,
                        thoughtText: runtime.currentThoughtText,
                        thoughtStyle: runtime.thoughtStyle
                    )
                    .onTapGesture {
                        runtime.clickPet()
                    }
                } else {
                    Text("Loading sprite...")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .frame(height: 280)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onEnded { value in
                        let geometrySize = CGSize(width: 420, height: 260)
                        runtime.placeToy(at: value.location, in: geometrySize)
                    }
            )
            .onAppear {
                runtime.setArenaSize(CGSize(width: 420, height: 260))
            }

            Text("Tip: Click the pet to interact, or drag anywhere in the arena to drop a toy target.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Controls")
                .font(.headline)

            HStack {
                Button("Click pet") { runtime.clickPet() }
                Button("Drop toy (random)") {
                    let x = CGFloat.random(in: 50...370)
                    let y = CGFloat.random(in: 60...220)
                    runtime.placeToy(at: CGPoint(x: x, y: y), in: CGSize(width: 420, height: 260))
                }
                Button("Reset") { runtime.reset() }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("Message source", selection: $selectedPlatform) {
                        Text("Slack").tag("Slack")
                        Text("Telegram").tag("Telegram")
                        Text("Peer").tag("Peer")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Button("Send test message") {
                        runtime.receiveMessage(
                            from: messageSender.isEmpty ? "friend" : messageSender,
                            text: messageText,
                            platform: selectedPlatform
                        )
                    }
                }

                HStack {
                    TextField("From", text: $messageSender)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 140)

                    TextField("Message", text: $messageText, axis: .horizontal)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent events")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(runtime.events, id: \.self) { event in
                        Text(event)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 160)
            .padding(10)
            .background(.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

private struct SpriteViewContainer: View {
    let image: Image
    let frameSize: CGSize
    let position: CGPoint
    let state: PetBuddyRuntime.State
    let thoughtText: String?
    let thoughtStyle: PetBuddyRuntime.ThoughtStyle

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let thoughtText {
                    ThoughtBubble(text: thoughtText, style: thoughtStyle)
                        .offset(
                            x: xInBounds(min: 24, max: geometry.size.width - 130, around: position.x),
                            y: yInBounds(min: 24, max: geometry.size.height - 30, around: position.y - frameSize.height * 2.5)
                        )
                }

                image
                    .resizable()
                    .interpolation(.none)
                    .frame(width: frameSize.width * 4, height: frameSize.height * 4)
                    .position(
                        x: xInBounds(min: 16, max: geometry.size.width - 16, around: position.x),
                        y: yInBounds(min: 16, max: geometry.size.height - 16, around: position.y)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                    .overlay(alignment: .center) {
                        if state == .walk {
                            Text("walk")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.75), in: Capsule())
                                .foregroundStyle(.white)
                                .offset(x: 8, y: -18)
                        }
                    }
            }
        }
    }

    private func xInBounds(min minX: CGFloat, max maxX: CGFloat, around value: CGFloat) -> CGFloat {
        max(minX, min(value, maxX))
    }

    private func yInBounds(min minY: CGFloat, max maxY: CGFloat, around value: CGFloat) -> CGFloat {
        max(minY, min(value, maxY))
    }
}

private struct ThoughtBubble: View {
    let text: String
    let style: PetBuddyRuntime.ThoughtStyle

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .padding(8)
            .frame(maxWidth: 180)
            .background(style.bubbleColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.black.opacity(0.2), lineWidth: 0.7)
            }
            .shadow(radius: 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(PetBuddyRuntime())
}
