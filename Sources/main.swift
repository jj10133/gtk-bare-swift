import Adwaita
import BareModule

@main
struct BareSwiftApp: App {

    let app = AdwaitaApp(id: "com.bare.swift")

    var scene: Scene {
        Window(id: "main") { window in
            Text("Hello World!!")

        }
        .defaultSize(width: 450, height: 300)
        .onAppear {
            Task.detached {
                initializeAndRunBare()
            }
        }
    }
}

func initializeAndRunBare() {

    // Note: The C-API requires a uv_loop_t. libuv must be linked
       // (which you handled in Package.swift with the -luv linker flag).
    var bare: UnsafeMutablePointer<bare_t>? = nil

        // --- 1. Setup Phase ---
        let uvLoop = uv_default_loop()
        let platform: UnsafeRawPointer? = nil
        let env: UnsafeRawPointer? = nil
        let options: UnsafeRawPointer? = nil
        var argc: Int32 = 0
        var argv: UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>? = nil

        // bare_setup will initialize the runtime
        let setupResult = bare_setup(uvLoop, platform, env, argc, argv, options, &bare)

        guard setupResult == 0, let b = bare else {
            print("❌ Bare setup failed!")
            return
        }

        print("✅ Bare runtime initialized successfully.")

        // --- 2. Load and Run Phase ---
        let filename = "main.js" // The JavaScript file Bare will execute

        // Convert Swift String to C String (must manage memory, this is a basic example)
        let cFilename = (filename as NSString).utf8String

        // Load a dummy script (you must ensure this file exists in the correct path
        // for Bare to find it at runtime).
        bare_load(b, cFilename, nil, nil)

        // bare_run starts the libuv event loop, which will block this Task.detached thread
        bare_run(b)

        // --- 3. Teardown Phase ---
        var exit_code: Int32 = 0
        bare_teardown(b, &exit_code)

        print("Bare runtime finished with exit code: \(exit_code)")
}
