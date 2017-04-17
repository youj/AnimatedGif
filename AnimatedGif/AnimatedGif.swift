import ScreenSaver
import GLUT
let LOAD_BTN = 0
let UNLOAD_BTN = 1
let VIEW_OPT_STRETCH_OPTIMAL = 0
let VIEW_OPT_STRETCH_MAXIMAL = 1
let VIEW_OPT_KEEP_ORIG_SIZE = 2
let VIEW_OPT_STRETCH_SMALL_SIDE = 3
let MAX_VIEW_OPT = 3
let SYNC_TO_VERTICAL = 1
let DONT_SYNC = 0
let FRAME_COUNT_NOT_USED = -1
let FIRST_FRAME = 0
let DEFAULT_ANIME_TIME_INTER = 1 / 15.0
let GL_ALPHA_OPAQUE = 1.0
let NS_ALPHA_OPAQUE = 1.0
class AnimatedGifView: ScreenSaverView {
    override init?(frame: NSRect, isPreview: Bool) {
        currFrameCount = FRAME_COUNT_NOT_USED
        super.init(frame: frame, isPreview: isPreview)
        // initalize screensaver defaults with an default value
        let defaults = ScreenSaverDefaults(name: Bundle(for: AnimatedGifView).bundleIdentifier)
        defaults.register(defaults: [
            "GifFileName" : "file:///please/select/an/gif/animation.gif",
            "GifFrameRate" : "15.0",
            "GifFrameRateManual" : "NO",
            "ViewOpt" : "0",
            "BackgrRed" : "0.0",
            "BackgrGreen" : "0.0",
            "BackgrBlue" : "0.0",
            "LoadAniToMem" : "NO"
            ]
        )
        
        glView = createGLView()
        animationTimeInterval = DEFAULT_ANIME_TIME_INTER
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    var viewOption: Int = 0
    var currFrameCount: Int = 0
    var maxFrameCount: Int = 0
    var imageFiles: [String]? = []
    var gifRep: NSBitmapImageRep?
    var backgrRed: Float = 0.0
    var backgrGreen: Float = 0.0
    var backgrBlue: Float = 0.0
    var loadAnimationToMem: Bool = false
    
    var glView: NSOpenGLView?
    @IBOutlet var optionsPanel: NSPanel!
    @IBOutlet var textFieldFileUrl: NSTextField!
    @IBOutlet var sliderFpsManual: NSSlider!
    @IBOutlet var checkButtonSetFpsManual: NSButton!
    @IBOutlet var checkButtonLoadIntoMem: NSButton!
    @IBOutlet var colorWellBackgrColor: NSColorWell!
    @IBOutlet var labelFpsManual: NSTextField!
    @IBOutlet var labelFpsGif: NSTextField!
    @IBOutlet var segmentButtonLaunchAgent: NSSegmentedControl!
    @IBOutlet var popupButtonViewOptions: NSPopUpButton!
    
    func createGLView() -> NSOpenGLView {
        let attribs: [NSOpenGLPixelFormatAttribute] = [UInt32(NSOpenGLPFADoubleBuffer), UInt32(NSOpenGLPFAAccelerated), 0]
        let format = NSOpenGLPixelFormat(attributes: attribs)
        let glview = NSOpenGLView(frame: NSZeroRect, pixelFormat: format)
        var swapInterval: GLInt = GLInt(SYNC_TO_VERTICAL)
        glview?.openGLContext?.setValues(swapInterval, for: NSOpenGLCPSwapInterval)
        return glview!
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        glView?.setFrameSize(newSize)
    }
    
    override func startAnimation() {
        
    }
    override func stopAnimation() {
        super.stopAnimation()
        if isPreview == false {
            // remove glview from screensaver view
            removeFromSuperview()
        }
        if (isPreview == false) && (loadAnimationToMem == true) {
            /*clean all precalulated bitmap images*/
            animationImages.removeAll()
            animationImages = nil
        }
        img = nil
        currFrameCount = FRAME_COUNT_NOT_USED
    }

//    func isOpaque() -> Bool {
//        return true
//    }

    @IBAction func selectSliderFpsManual(_ sender: Any) {
        // update label with actual selected value of slider
        labelFpsManual.stringValue = sliderFpsManual.stringValue
    }
    
    @IBAction func pressCheckboxSetFpsManual(_ sender: Any) {
        // enable or disable slider depending on checkbox
        let frameRateManual: Bool = checkButtonSetFpsManual.state > 0
        if frameRateManual {
            sliderFpsManual.isEnabled = true
        }
        else {
            sliderFpsManual.isEnabled = false
        }
    }

    @IBAction func closeConfigCancel(_ sender: Any) {
        // close color dialog and options dialog
        NSColorPanel.shared().close()
        NSApplication.shared.endSheet(optionsPanel)
    }

    @IBAction func closeConfigOk(_ sender: Any) {
        // read values from GUI elements
        let frameRate = CFloat(sliderFpsManual)
        let gifFileName: String = textFieldFileUrl.stringValue
        let frameRateManual: Bool = checkButtonSetFpsManual.state
        let loadAniToMem: Bool = checkButtonLoadIntoMem.state
        let viewOpt: Int = popupButtonViewOptions.selectedTag
        let colorPicked: NSColor? = colorWellBackgrColor.color
        // write values back to screensver defaults
        let defaults = ScreenSaverDefaults(name: Bundle(for: type(of: self)).bundleIdentifier)
        defaults["GifFileName"] = gifFileName
        defaults.set(frameRate, forKey: "GifFrameRate")
        defaults.set(frameRateManual, forKey: "GifFrameRateManual")
        defaults.set(loadAniToMem, forKey: "LoadAniToMem")
        defaults.set(viewOpt, forKey: "ViewOpt")
        defaults.set(colorPicked?.redComponent, forKey: "BackgrRed")
        defaults.set(colorPicked.greenComponent, forKey: "BackgrGreen")
        defaults.set(colorPicked.blueComponent, forKey: "BackgrBlue")
        defaults.synchronize()
        // set new values to object attributes
        viewOption = viewOpt
        backgrRed = colorPicked.redComponent
        backgrGreen = colorPicked.greenComponent
        backgrBlue = colorPicked.blueComponent
        // close color dialog and options dialog
        NSColorPanel.shared().close()
        NSApplication.shared.endSheet(optionsPanel)
    }
    
    @IBAction func navigateSegmentButton(_ sender: Any) {
        // check witch segment of segment button was pressed and than start the according method
        let control: NSSegmentedControl? = (sender as? NSSegmentedControl)
        let selectedSeg: Int? = control?.selectedSegment()
        switch selectedSeg {
        case LOAD_BTN:
            loadAgent()
        case UNLOAD_BTN:
            unloadAgent()
        default:
            break
        }
        
    }
    
    func hasConfigureSheet() -> Bool {
        return true
    }

    @IBAction func sendFileButtonAction(_ sender: Any) {
        let openDlg = NSOpenPanel()
        openDlg.canChooseFiles = true
        openDlg.canChooseDirectories = false
        openDlg.allowsMultipleSelection = false
        openDlg.directoryURL = URL(string: textFieldFileUrl.stringValue)
        openDlg.allowedFileTypes = ["gif", "GIF"]
        if openDlg.runModal() == NSOKButton {
            let files: [Any] = openDlg.urls
            textFieldFileUrl.stringValue = files[0]
            let source: CGImageSourceRef? = CGImageSourceCreateWithURL((URL(string: textFieldFileUrl.stringValue) as? CFURLRef), nil)
            if source != nil {
                let cfdProperties: CFDictionary = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                let properties: [AnyHashable: Any] = CFBridgingRelease(cfdProperties)
                let duration: Float? = CDouble(((properties[(kCGImagePropertyGIFDictionary as? String)!] as? Float)?[(kCGImagePropertyGIFUnclampedDelayTime as? String)] as? Float))
                var fps: Float = 1 / duration!
                labelFpsGif.stringValue = String(format: "%2.1f", fps)
            } else {
                labelFpsGif.stringValue = "0.0"
            }
        }
    }


    
    deinit {
        glView?.removeFromSuperview()
        glView = nil
    }
    
    func pictureRatio(fromWidth iWidth: Float, andHeight iHeight: Float) -> Float {
        return iWidth / iHeight
    }
    
    func calcWidth(fromRatio iRatio: Float, andHeight iHeight: Float) -> Float {
        return iRatio * iHeight
    }
    
    func calcHeight(fromRatio iRatio: Float, andWidth iWidth: Float) -> Float {
        return iWidth / iRatio
    }

    
    func loadAgent() {
        // create the plist agent file
        var plist = [AnyHashable: Any]()
        // check if LaunchAgend directory is there or not
        let userLaunchAgentsDir: String = "\("/Users/")\(NSUserName())\("/Library/LaunchAgents")"
        let launchAgentDirExists: Bool = FileManager.default.fileExists(atPath: userLaunchAgentsDir)
        if launchAgentDirExists == false {
            // if directory is not there create it
            try? FileManager.default.createDirectory(atPath: userLaunchAgentsDir, withIntermediateDirectories: true, attributes: nil)
        }
        // set values here...
        let cfg: [AnyHashable: Any] = ["Label": "com.stino.animatedgif", "ProgramArguments": ["/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine", "-background"], "KeepAlive": ["OtherJobEnabled": ["com.apple.SystemUIServer.agent": true, "com.apple.Finder": true, "com.apple.Dock.agent": true]], "ThrottleInterval": 0]
        var userLaunchAgentsPath: String = "\("/Users/")\(NSUserName())\("/Library/LaunchAgents/com.stino.animatedgif.plist")"
        plist.write(toFile: userLaunchAgentsPath, atomically: true)
        plist.removeAll()

    }
    
    func unloadAgent() {
        // stop the launch agent
        let userLaunchAgentsPath: String = "\("/Users/")\(NSUserName())\("/Library/LaunchAgents/com.stino.animatedgif.plist")"
        let cmdstr: String = "\("launchctl unload ")\(userLaunchAgentsPath)"
        system(cmdstr.cString(using: String.Encoding.utf8))
        // remove the plist agent file
        try? FileManager.default.removeItem(atPath: userLaunchAgentsPath)
    }

}
