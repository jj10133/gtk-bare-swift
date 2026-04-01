import Adwaita
import BareSDK
import Foundation

// ── BareWorklet wrapper ───────────────────────────────────────────────────────

class BareWorklet {
    private var worklet: UnsafeMutablePointer<bare_worklet_t>? = nil
    private var ipc: UnsafeMutablePointer<bare_ipc_t>? = nil
    private var poll: UnsafeMutablePointer<bare_ipc_poll_t>? = nil

    var onData: ((String) -> Void)?

    func start(jsPath: String, source: String) {
        bare_worklet_alloc(&worklet)
        var opts = bare_worklet_options_t()
        opts.memory_limit = 32 * 1024 * 1024
        bare_worklet_init(worklet, &opts)

        var sourceData = Array(source.utf8).map { Int8(bitPattern: $0) }
        sourceData.withUnsafeMutableBufferPointer { buf in
            var uvBuf = uv_buf_init(buf.baseAddress, UInt32(buf.count))
            jsPath.withCString { path in
                _ = bare_worklet_start(worklet, path, &uvBuf, 0, nil)
            }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Debug — check if fds are set
        if let w = worklet {
            print("[bare] worklet incoming fd: \(w.pointee.incoming)")
            print("[bare] worklet outgoing fd: \(w.pointee.outgoing)")
        }

        bare_ipc_alloc(&ipc)
        bare_ipc_init(ipc, worklet)
        bare_ipc_poll_alloc(&poll)
        bare_ipc_poll_init(poll, ipc)

        let ctx = Unmanaged.passRetained(self).toOpaque()
        bare_ipc_poll_set_data(poll, ctx)

        bare_ipc_poll_start(poll, Int32(bare_ipc_readable)) { pollPtr, events in
            guard let pollPtr = pollPtr else { return }
            guard (events & Int32(bare_ipc_readable)) != 0 else { return }
            let ctx = bare_ipc_poll_get_data(pollPtr)!
            let self_ = Unmanaged<BareWorklet>.fromOpaque(ctx).takeUnretainedValue()
            let ipcPtr = bare_ipc_poll_get_ipc(pollPtr)!
            var dataPtr: UnsafeMutableRawPointer? = nil
            var len: Int = 0
            while bare_ipc_read(ipcPtr, &dataPtr, &len) == 0,
                let data = dataPtr, len > 0
            {
                let str =
                    String(
                        bytesNoCopy: data, length: len,
                        encoding: .utf8, freeWhenDone: false) ?? ""
                DispatchQueue.main.async { self_.onData?(str) }
            }
        }

        // Drain any data already written by JS before poll was set up
        if let ipcPtr = ipc {
            var dataPtr: UnsafeMutableRawPointer? = nil
            var len: Int = 0
            while bare_ipc_read(ipcPtr, &dataPtr, &len) == 0,
                let data = dataPtr, len > 0
            {
                let str =
                    String(
                        bytesNoCopy: data, length: len,
                        encoding: .utf8, freeWhenDone: false) ?? ""
                print("[bare] drained: \(str)")
                DispatchQueue.main.async { self.onData?(str) }
            }
        }
    }

    func send(_ text: String) {
        guard let ipc = ipc else { return }
        var bytes = Array(text.utf8).map { Int8(bitPattern: $0) }
        bytes.withUnsafeMutableBufferPointer { buf in
            _ = bare_ipc_write(ipc, buf.baseAddress, buf.count)
        }
    }

    func suspend(linger: Int32 = 0) { if let w = worklet { bare_worklet_suspend(w, linger) } }
    func resume() { if let w = worklet { bare_worklet_resume(w) } }
    func terminate() { if let w = worklet { bare_worklet_terminate(w) } }
}

// ── JS source ─────────────────────────────────────────────────────────────────

let jsSource = """
    const { IPC } = BareKit

    console.log("hello from bare")

    IPC.write(Buffer.from('Hello from Bare JS on Linux!'))
    IPC.write(Buffer.from('Bare version: ' + Bare.versions.bare))

    IPC.on('data', (data) => {
        IPC.write(Buffer.from('JS received: ' + data.toString()))
    })
    """

// ── App ───────────────────────────────────────────────────────────────────────

let worklet = BareWorklet()

@main
struct BareSwiftApp: App {
    let app = AdwaitaApp(id: "com.bare.swift")

    var scene: Scene {
        Window(id: "main") { _ in
            ContentView(worklet: worklet)
        }
        .title("Bare JS + Swift + GTK")
        .defaultSize(width: 600, height: 420)
    }
}

struct ContentView: View {
    let worklet: BareWorklet
    @State private var log = ""
    @State private var input = ""
    @State private var ready = false

    var view: Body {
        VStack {
            // Status
            Text(ready ? "🟢  JS runtime ready" : "⏳  Starting Bare JS...")
                .padding()

            // Log view
            ScrolledWindow {
                Text(log.isEmpty ? "(waiting for JS messages...)" : log)
                    .wrap()
                    .xalign(0)
                    .padding()
            }
            .vexpand()

            // Input — SearchEntry with .text() binding + .activate() for Enter key
            SearchEntry()
                .text($input)
                .placeholderText("Type a message, press Enter to send...")
                .activate {
                    guard !input.isEmpty else { return }
                    log += "[gtk] \(input)\n"
                    worklet.send(input)
                    input = ""
                }
                .padding()
        }
        .onAppear {
            worklet.onData = { text in
                log += "[js]  \(text)\n"
                if !ready { ready = true }
            }
            Thread.detachNewThread {
                worklet.start(jsPath: "/app.js", source: jsSource)
            }
        }
    }
}
