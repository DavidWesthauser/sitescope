import SwiftUI
import RealityKit
import UniformTypeIdentifiers
import PhotosUI

enum ARMode: String, Identifiable { case mapping, editing, walkthrough; var id: String { rawValue } }
struct CameraView: UIViewRepresentable {
    let controller: ARController
    func makeUIView(context: Context) -> ARView { controller.view }
    func updateUIView(_ uiView: ARView, context: Context) {}
}
/// Keeps the phone awake while AR is open and confirms scan/recognition milestones with haptics.
private struct ARSessionFeedback: ViewModifier {
    @ObservedObject var ar: ARController
    func body(content: Content) -> some View {
        content
            // Scans take minutes; auto-lock would pause AR mid-scan.
            .onAppear { UIApplication.shared.isIdleTimerDisabled=true }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled=false }
            .persistentSystemOverlays(.hidden)
            .sensoryFeedback(.selection,trigger:ar.scan.coverage.headings.count) { old,new in new>old }
            .sensoryFeedback(.selection,trigger:ar.scan.coverage.positions.count) { old,new in new>old }
            .sensoryFeedback(.success,trigger:ar.scan.canFinish) { _,ready in ready }
            .sensoryFeedback(.success,trigger:ar.localization.state) { old,new in new == .aligned && old != .aligned }
    }
}
private struct ToolsHeightPreference: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value:inout CGFloat,nextValue:()->CGFloat) { value=max(value,nextValue()) }
}
private struct CameraAimPreference: PreferenceKey {
    static let defaultValue: CGPoint? = nil
    static func reduce(value:inout CGPoint?,nextValue:()->CGPoint?) { value=nextValue() ?? value }
}
struct ARScreen: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @Environment(\.dynamicTypeSize) private var typeSize
    @StateObject private var ar: ARController
    let manager: Bool
    private let startSession: Bool
    private var room: Room { ar.room }
    private var mode: ARMode { ar.mode }
    @State private var title = ""; @State private var detail = ""
    @State private var replacing: Annotation?
    @State private var priority = 1
    @State private var distance: Double = 1
    @State private var manualDistance = false
    @State private var importing = false
    @State private var taskList = false; @State private var closing = false
    @State private var saving = false
    @State private var tools = true
    @State private var pickingPhoto=false
    @State private var photoSelection: PhotosPickerItem?
    @State private var scanMore = false
    @State private var showingScanOptions=false
    @State private var showingWorkDetails=false
    @State private var showingPlacement=false
    @State private var restartingScan=false
    @State private var showingScanGuide=false
    @State private var scanGuideImage:UIImage?
    @State private var toolsHeight:CGFloat=0
    init(room: Room, mode: ARMode, manager: Bool) {
        self.manager = manager; startSession=true
        _ar = StateObject(wrappedValue: ARController(room: room, mode: mode))
    }
    // Tests inject deterministic states without starting a camera or inventing maps in real flows.
    init(controller:ARController,manager:Bool) {
        self.manager=manager; startSession=false; _ar=StateObject(wrappedValue:controller)
    }
    private var statusTitle: String {
        if !ar.trackingNormal && ar.ready { return ar.trackingIssue.title }
        switch ar.localization.state {
        // Right after a scan the room was never "recognized"; it is the map that was just saved.
        case .aligned: return ar.scannedThisSession ? "Room map saved" : "Room recognized"
        case .failed: return "Room not recognized"
        case .lost: return "Tracking lost"
        default: return ar.scannedThisSession ? "Reconnecting to the room…" : "Recognizing room…"
        }
    }
    var body: some View {
        ZStack {
            CameraView(controller: ar).ignoresSafeArea()
            if let frame = ar.frozenFrame { FrozenDrawingView(ar:ar,frame:frame).ignoresSafeArea() }
            if mode == .mapping {
                scanOverlay
            } else {
            VStack(spacing: 8) {
                HStack(spacing:8) {
                    Button { closing=true } label: { Image(systemName:"xmark").font(.system(size:20,weight:.semibold)).frame(width:44,height:44) }.accessibilityLabel("Close")
                    Text(room.name).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8).frame(maxWidth:.infinity)
                    Button { ar.resumeCamera(); taskList=true } label: { Image(systemName:"list.bullet").font(.system(size:20,weight:.semibold)).frame(width:44,height:44) }.accessibilityLabel("Tasks")
                }.padding(.horizontal,8).background(.regularMaterial,in:RoundedRectangle(cornerRadius:14))
                VStack(alignment:.leading,spacing:5) {
                    Label(statusTitle,systemImage:ar.localization.state == .aligned ? "checkmark.circle.fill" : "viewfinder").font(.subheadline.weight(.semibold))
                    if ar.localization.state != .aligned { Text(ar.guidance).font(.caption).lineLimit(3).fixedSize(horizontal:false,vertical:true) }
                    // Like Apple's relocalization sample, show the saved view right away instead of behind a button.
                    if ar.localization.state != .aligned,room.scan_guide_jpeg != nil {
                        Button {
                            if scanGuideImage != nil { showingScanGuide=true }
                            else { ar.error="The saved viewpoint photo could not be opened. Continue looking for familiar room details." }
                        } label: {
                            HStack(spacing:10) {
                                if let scanGuideImage {
                                    Image(uiImage:scanGuideImage).resizable().scaledToFill().frame(width:44,height:58)
                                        .clipShape(RoundedRectangle(cornerRadius:6)).accessibilityHidden(true)
                                } else { Image(systemName:"photo").frame(width:44) }
                                VStack(alignment:.leading,spacing:2) {
                                    Text("Match this saved view").font(.caption.weight(.semibold))
                                    Text("Tap to enlarge").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }.buttonStyle(.plain).frame(minHeight:44,alignment:.leading).accessibilityIdentifier("room.scanGuide")
                    }
                    if ar.loadingSavedImages { Text("Loading image instructions…").font(.caption).foregroundStyle(.secondary) }
                    if ar.hiddenImageCount>0 { Text("\(ar.hiddenImageCount) image instructions shown as outlines to save memory. Their tasks stay in the list.").font(.caption).foregroundStyle(.secondary) }
                }.frame(maxWidth:.infinity,alignment:.leading).padding(10).background(.regularMaterial,in:RoundedRectangle(cornerRadius:14))
                GeometryReader { proxy in
                    ZStack {
                        Color.clear
                        if mode == .editing { Image(systemName:"plus").font(.system(size:20,weight:.semibold)).foregroundStyle(.white).shadow(radius:2).accessibilityHidden(true) }
                    }.preference(key:CameraAimPreference.self,value:CGPoint(x:proxy.frame(in:.global).midX,y:proxy.frame(in:.global).midY))
                }.frame(minHeight:44).allowsHitTesting(false)
                if scanMore { ScanOverview(progress: ar.scan) }
                if tools {
                    VStack(spacing:0) {
                    // Size to the measured content; scroll only when it exceeds the cap. One view identity keeps control state.
                    ScrollView {
                        toolsContent.background(GeometryReader { proxy in Color.clear.preference(key:ToolsHeightPreference.self,value:proxy.size.height) })
                    }.scrollIndicators(.visible).scrollBounceBehavior(.basedOnSize)
                    .frame(height:min(max(toolsHeight,44),mode == .walkthrough ? 120 : 200))
                    .onPreferenceChange(ToolsHeightPreference.self) { toolsHeight=$0 }
                    if mode == .editing && ar.localization.state == .aligned && !scanMore { Divider(); saveBar.padding(.horizontal,12).padding(.vertical,8) }
                    }.frame(maxWidth:.infinity).background(.regularMaterial,in:RoundedRectangle(cornerRadius:14))
                }
                Button("Tools",systemImage:tools ? "chevron.down" : "chevron.up") { tools.toggle() }.font(.caption).padding(.horizontal,12).frame(minHeight:44).background(.regularMaterial,in:Capsule()).accessibilityLabel(tools ? "Hide tools" : "Show tools")
            }.padding(.horizontal, 12).padding(.bottom, 8)
            }
            if saving { Color.black.opacity(0.3).ignoresSafeArea(); ProgressView("Saving room…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) }
        }
        .onPreferenceChange(CameraAimPreference.self) { point in if let point { ar.aimPoint=ar.view.convert(point,from:nil) } }
        .task { if startSession { await ar.prepare(store:store) } }
        .task(id:room.scan_guide_jpeg) { scanGuideImage=room.scan_guide_jpeg.flatMap(ScanGuideImage.thumbnail) }
        .onDisappear { ar.stop() }
        .modifier(ARSessionFeedback(ar:ar))
        .onChange(of:title) { _, value in ar.draftText=value }
        .sheet(isPresented:$showingWorkDetails) { DrawingWorkDetails(title:$title,details:$detail,priority:$priority) }
        .sheet(isPresented:$showingPlacement) { DrawingPlacementSettings(measured:$manualDistance,distance:$distance) }
        .photosPicker(isPresented:$pickingPhoto,selection:$photoSelection,matching:.images)
        .onChange(of:photoSelection) { _,item in
            guard let item else { return }
            let request=ar.beginImageRequest()
            Task {
                defer { ar.finishImageRequest(request) }
                do { guard let data=try await item.loadTransferable(type:Data.self) else { throw AppError.message("Could not load this image.") }; try await ar.setImage(data,request:request) }
                catch { if ar.imageRequestIsCurrent(request) { ar.error=error.localizedDescription } }
            }
        }
        // Only real backgrounding pauses AR. `.inactive` (Control Center, notification banners, system alerts) keeps the session running.
        .onChange(of: phase) { _, phase in if phase == .active { ar.resume() } else if phase == .background { ar.suspend() } }
        .alert("AR guidance", isPresented: Binding(get: { ar.error != nil }, set: { if !$0 { ar.error = nil } })) { Button("OK") { ar.error = nil } } message: { Text(ar.error ?? "") }
        .confirmationDialog(mode == .mapping ? "Leave this unsaved scan?" : (ar.draft.isEmpty ? "Close AR? Saved drawings will be kept." : "Discard unsaved drawing and close AR?"), isPresented: $closing, titleVisibility: .visible) {
            Button("Close AR", role: ar.draft.isEmpty && mode != .mapping ? nil : .destructive) { dismiss() }
        }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.png,.jpeg]) { result in
            do {
                let url=try result.get()
                guard url.startAccessingSecurityScopedResource() else { throw AppError.message("Cannot read selected file.") }
                defer { url.stopAccessingSecurityScopedResource() }
                let data=try Data(contentsOf:url,options:.mappedIfSafe)
                let request=ar.beginImageRequest()
                Task { defer { ar.finishImageRequest(request) };do { try await ar.setImage(data,request:request) } catch { if ar.imageRequestIsCurrent(request) { ar.error=error.localizedDescription } } }
            } catch { ar.error=error.localizedDescription }
        }
        .sheet(isPresented: $taskList, onDismiss: { Task { await reload() } }) {
            NavigationStack {
                List(ar.annotations) { item in NavigationLink { TaskEditor(item: item, room: room, manager: manager) } label: { Label(item.title, systemImage: item.status == .completed ? "checkmark.circle.fill" : "circle") } }
                    .navigationTitle("Room tasks").toolbar { Button("Done") { taskList = false } }
            }.environmentObject(store)
        }
        .sheet(isPresented:$showingScanGuide) {
            NavigationStack {
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        if let scanGuideImage { Image(uiImage:scanGuideImage).resizable().scaledToFit().accessibilityLabel("Photo saved during the original room scan") }
                        Text("Find this view in the room, then look around the same details. The photo is a visual guide; ARKit still needs to recognize the room before drawings appear.")
                            .font(.body)
                    }.padding()
                }.navigationTitle("Saved viewpoint").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { showingScanGuide=false } } }
            }
        }
        .sheet(item: $ar.selected, onDismiss: { Task { await reload() } }) { item in
            NavigationStack { TaskEditor(item: item, room: room, manager: manager, onReposition: mode == .editing && [.line,.area,.image].contains(item.kind) ? {
                guard ar.draft.isEmpty else { ar.error="Save or clear your current drawing before repositioning another instruction.";return }
                replacing = item; ar.clearDraft(); ar.tool = item.kind; title = item.title; detail = item.detail; priority = item.priority; tools = true
                if item.kind == .image {
                    let request=ar.beginImageRequest(clearExisting:true)
                    Task { defer { ar.finishImageRequest(request) }; do { try await ar.restoreImageDraft(item,store:store,request:request) } catch { if ar.imageRequestIsCurrent(request) { ar.error=error.localizedDescription } } }
                }
            } : nil) }.environmentObject(store)
        }
    }
    private var toolsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if ar.localization.state == .aligned {
                if mode == .editing {
                    if scanMore {
                        Text("Move around missed walls and corners. Outlines show detected patches, not full-room coverage.").font(.caption)
                        Button("Back to drawing") { scanMore=false; ar.showSurfaceGuides=false }
                    } else { editorTools }
                    Button(scanMore ? "Hide scan overview" : "Scan more surfaces") { ar.resumeCamera(); scanMore.toggle(); ar.showSurfaceGuides=scanMore }.font(.caption)
                } else { Toggle("Show surface outlines", isOn: $ar.showSurfaceGuides).font(.caption) }
                Button("Restart recognition") { ar.startMap() }.font(.caption)
            } else if ar.mapAvailable {
                if ar.localization.state == .failed {
                    Button("Keep searching") { ar.continueSearching() }.buttonStyle(.borderedProminent)
                }
                Button("Restart recognition") { ar.startMap() }.buttonStyle(.bordered).disabled(!ar.ready)
            } else {
                if ar.ready { Text("No saved room map. Use the task list, or ask the manager to scan this room.").font(.caption) }
                else { ProgressView().frame(maxWidth:.infinity).accessibilityLabel("Starting camera") }
            }
        }.frame(maxWidth:.infinity,alignment:.leading).padding()
    }
    private var scanCoachTitle:String {
        if ar.trackingIssue == .unavailable { return "AR unavailable" }
        if !ar.ready { return "Starting camera" }
        if ar.ready,ar.trackingIssue != .none { return ar.trackingIssue.title }
        if !ar.scan.normalTracking { return "Move slowly to begin" }
        if !ar.scan.hasUsefulFeatures { return "Find a textured corner" }
        if ar.scan.coverage.positions.count<3 { return "Walk around the room" }
        if ar.scan.coverage.headings.count<4 { return "Look in every direction" }
        return "Revisit a familiar corner"
    }
    private var scanOverlay: some View {
        ZStack {
            VStack(spacing:0) {
                LinearGradient(colors:[.black.opacity(0.35),.clear],startPoint:.top,endPoint:.bottom).frame(height:180)
                Spacer()
                LinearGradient(colors:[.clear,.black.opacity(0.18)],startPoint:.top,endPoint:.bottom).frame(height:180)
            }.ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing:12) {
                HStack {
                    Button("Cancel") { closing=true }.frame(minWidth:44,minHeight:44).accessibilityLabel("Close")
                    Spacer()
                    Button { saveRoom() } label: {
                        Text("Finish").fontWeight(.semibold).frame(minWidth:64,minHeight:44)
                    }.disabled(!ar.scan.canFinish || saving).opacity(ar.scan.canFinish && !saving ? 1 : 0.35).accessibilityIdentifier("scan.finish")
                        .animation(.easeInOut(duration:0.25),value:ar.scan.canFinish)
                }.font(.body).buttonStyle(.plain).shadow(color:.black.opacity(0.5),radius:3,y:1)
                if !ar.scan.canFinish || (ar.ready && ar.trackingIssue != .none) {
                    Label(scanCoachTitle,systemImage:ar.trackingIssue == .excessiveMotion ? "hand.raised" : "viewfinder")
                        .font(.subheadline.weight(.medium)).multilineTextAlignment(.center).lineLimit(2).fixedSize(horizontal:false,vertical:true)
                        .padding(.horizontal,16).padding(.vertical,10)
                        .background(.ultraThinMaterial,in:Capsule()).frame(maxWidth:320)
                        .accessibilityLabel(ar.guidance)
                        .animation(.easeInOut(duration:0.2),value:scanCoachTitle)
                    HStack(spacing:6) {
                        ForEach(0..<4,id: \.self) { heading in
                            let progress=ar.scan.coverage.directionProgress[heading]
                            GeometryReader { geometry in
                                Capsule().fill(.white.opacity(0.25))
                                    .overlay(alignment:.leading) {
                                        Capsule().fill(.mint).frame(width:geometry.size.width*progress)
                                            .animation(.linear(duration:0.25),value:progress)
                                    }
                            }.frame(height:4)
                                .accessibilityLabel("View \(heading+1): \(progress >= 1 ? "recorded" : "pending")")
                        }
                    }.frame(maxWidth:180).accessibilityElement(children:.combine)
                    if ar.scan.normalTracking && ar.scan.hasUsefulFeatures {
                        Text("Pause briefly at each view · \(min(ar.scan.coverage.positions.count,3))/3 positions")
                            .font(.caption).shadow(color:.black,radius:2).multilineTextAlignment(.center)
                    }
                }
                GeometryReader { proxy in
                    Color.clear.preference(key:CameraAimPreference.self,value:CGPoint(x:proxy.frame(in:.global).midX,y:proxy.frame(in:.global).midY))
                }.frame(minHeight:44).allowsHitTesting(false)
                ScanOverview(progress:ar.scan)
                HStack {
                    Button { showingScanOptions=true } label: {
                        Image(systemName:"slider.horizontal.3").font(.system(size:18,weight:.medium)).frame(width:44,height:44)
                            .background(.black.opacity(0.16),in:Circle())
                    }.buttonStyle(.plain).accessibilityLabel("Scan options and progress")
                    Spacer()
                }
            }.padding(.horizontal,20).padding(.bottom,8)
        }.foregroundStyle(.white).environment(\.colorScheme,.dark)
        .sheet(isPresented:$showingScanOptions) {
            NavigationStack {
                Form {
                    Section("Scan progress") {
                        LabeledContent("Room map",value:ar.scan.mapReady ? "Ready" : "Building")
                        LabeledContent("Directions",value:"\(ar.scan.coverage.headings.count) of 4")
                        LabeledContent("Positions",value:"\(min(ar.scan.coverage.positions.count,3)) of 3")
                        LabeledContent("Visible detail",value:ar.scan.hasUsefulFeatures ? "Enough for this view" : "Find more texture")
                        LabeledContent("Surface outlines",value:"\(ar.scan.surfaces.count) nearby")
                        Text("Pause for about a second at each textured view. Each bar records a viewing direction, not a completed wall. Visit three positions at least 0.5 m apart. The miniature shows detected patches, not proof of complete room coverage.").font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Tracking") {
                        if ar.renderingReduced { Text("Scan detail was reduced to limit rendering work. Finish this room before scanning another. Your map and drawings are retained.").font(.footnote) }
                        Text(ar.trackingIssue == .none ? "Tracking is stable. Continue scanning from overlapping viewpoints." : ar.trackingIssue.instruction)
                        Button("Restart scan",role:.destructive) { restartingScan=true }
                    }
                    Section("Room recognition") {
                        Toggle("Save a viewpoint photo",isOn:$ar.saveScanGuide).disabled(!ar.canChangeScanGuide)
                        Text(ar.canChangeScanGuide ? "A small photo helps a technician find a familiar view. It is included when the project is exported." : "This save attempt already captured its map and photo. Restart the scan to change the photo choice.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .confirmationDialog("Restart and discard this unsaved scan?",isPresented:$restartingScan,titleVisibility:.visible) {
                    Button("Restart scan",role:.destructive) { showingScanOptions=false;ar.startMapping() }
                }
                    .navigationTitle("Scan options").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { showingScanOptions=false } } }
            }
        }
    }
    private var captureControls: some View {
        VStack(alignment: .leading) {
            Button(ar.tool == .area ? "Add corner at crosshair" : "Place at crosshair", systemImage: "scope") { ar.capture(distance: manualDistance ? Float(distance) : nil) }
                .buttonStyle(.bordered).disabled(!ar.trackingNormal || (manualDistance && (!distance.isFinite || distance < 0.1 || distance > 10)))
            Button("Placement settings",systemImage:"ruler") { showingPlacement=true }.font(.caption)
        }
    }
    private var editorTools: some View {
        VStack(alignment:.leading,spacing:10) {
            if let replacing { Text("Repositioning: \(replacing.title)").font(.headline); Button("Cancel") { self.replacing=nil; ar.cancelImageRequest();ar.clearDraft(); ar.resumeCamera(); title=""; detail="" } }
            Picker("Tool",selection:Binding(get:{ar.tool},set:{ selectTool($0) })) {
                Text("Draw").tag(AnnotationKind.line); Text("Area").tag(AnnotationKind.area); Text("Image").tag(AnnotationKind.image)
            }.pickerStyle(.segmented).accessibilityIdentifier("drawing.tools")
            ViewThatFits(in:.horizontal) {
                HStack { lockButton.fixedSize(); if ar.tool == .image { Spacer(); imageButton.fixedSize() } }
                VStack(alignment:.leading,spacing:8) { lockButton; if ar.tool == .image { imageButton } }
            }
            if ar.tool == .image {
                if ar.imageLoading { ProgressView("Loading image…") }
                else if let image=ar.draftImage {
                    HStack(spacing:10) {
                        Image(uiImage:image).resizable().scaledToFit().frame(width:44,height:40).accessibilityHidden(true)
                        VStack(alignment:.leading) { Text("Width").font(.caption); Text("\(ar.imageWidth,format:.number.precision(.fractionLength(2))) m").font(.caption.monospacedDigit()) }
                        Spacer(minLength:4)
                        let maximum=min(Float(3),3/Float(image.size.height/image.size.width))
                        Stepper("Image width",value:$ar.imageWidth,in:min(0.05,maximum)...maximum,step:0.05).labelsHidden().fixedSize().accessibilityLabel("Image width")
                    }
                }
                Text("Tap a detected surface to place the image.").font(.caption).fixedSize(horizontal:false,vertical:true)
                Button("Choose from Files",systemImage:"folder") { importing=true }.font(.subheadline)
            } else {
                Text(ar.tool == .line ? "Drag to draw. Lift your finger to end the stroke." : "Tap the corners of an area.").font(.caption)
            }
            if ar.drawingPlane == nil {
                Label(ar.surfaceTarget,systemImage:"scope").font(.caption).foregroundStyle(.secondary)
            } else {
                Label("Drawing surface locked",systemImage:"lock.fill").font(.caption).foregroundStyle(.secondary)
            }
            if ar.tool != .line { DisclosureGroup("Precise placement") { captureControls } }
            Button("Work details",systemImage:"text.alignleft") { showingWorkDetails=true }.font(.subheadline).frame(minHeight:44)
        }
    }
    private var lockButton: some View {
        Button(ar.lockingView ? "Locking…" : (ar.frozenFrame == nil ? "Lock view" : "Live camera"),systemImage:ar.frozenFrame == nil ? "viewfinder" : "camera") { ar.freezeView() }
            .font(.subheadline).lineLimit(1).disabled(ar.lockingView || !ar.trackingNormal || (ar.frozenFrame == nil && !ar.targetReady)).accessibilityIdentifier("drawing.lock").frame(minHeight:44)
    }
    private var imageButton: some View {
        Button("Choose image",systemImage:"photo") { pickingPhoto=true }.font(.subheadline).lineLimit(1).frame(minHeight:44).accessibilityIdentifier("drawing.image")
    }
    private var saveBar: some View {
        HStack(spacing:10) {
            Button { ar.undoPoint() } label: { Image(systemName:"arrow.uturn.backward").frame(width:22,height:22) }
                .buttonStyle(.bordered).frame(minWidth:44,minHeight:44).accessibilityLabel(ar.tool == .line ? "Undo stroke" : "Undo").disabled(ar.draft.isEmpty)
            Button { ar.clearDraft() } label: { Image(systemName:"trash").frame(width:22,height:22) }
                .buttonStyle(.bordered).frame(minWidth:44,minHeight:44).accessibilityLabel("Clear drawing").disabled(ar.draft.isEmpty && ar.drawingPlane == nil)
            Button { saveDrawing() } label: { Label("Save",systemImage:"checkmark").font(.headline).lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth:.infinity,minHeight:36) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("drawing.save").disabled(ar.draft.isEmpty || saving || ar.imageLoading || (ar.tool == .image && ar.imageData == nil))
        }
    }
    private func selectTool(_ kind:AnnotationKind) {
        guard kind == ar.tool || ar.draft.isEmpty else { ar.error="Save or clear the current drawing first."; return }
        if kind != .image && ar.tool == .image { ar.cancelImageRequest() }
        ar.tool=kind
        if kind == .image && ar.draftImage == nil { pickingPhoto=true }
    }
    private func saveDrawing() {
        saving = true
        Task {
            defer { saving = false }
            do {
                let label = title.trimmingCharacters(in: .whitespacesAndNewlines)
                var attachment:SpatialImage?
                if ar.tool == .image {
                    guard ar.imageData != nil else { pickingPhoto=true; return }
                    let path="\(room.project_id.uuidString.lowercased())/\(room.id.uuidString.lowercased())/\(UUID().uuidString.lowercased()).png"
                    attachment=SpatialImage(path:path,width:ar.imageWidth,height:ar.imageHeight)
                }
                var item = try ar.makeAnnotation(kind: ar.tool, title: label.isEmpty ? (ar.tool == .area ? "Area marking" : (ar.tool == .image ? "Image" : "Drawing")) : label, detail: detail, priority: priority,image:attachment)
                if let attachment,let data=ar.imageData {
                    try await store.uploadAsset(path:attachment.path,data:data,type:"image/png")
                }
                if let replacing { item.id = replacing.id; item.status = replacing.status }
                try await store.saveInstruction(item, room: room, replacing: replacing != nil)
                replacing = nil; ar.clearDraft(); ar.resumeCamera(); title = ""; detail = ""; await reload()
            } catch { ar.error = error.localizedDescription }
        }
    }
    private func saveRoom() {
        saving = true
        Task {
            defer { saving = false }
            do { let updated = try await ar.saveMap(store: store); ar.beginEditing(updated) }
            catch MapSaveTransaction.Failure.savedSessionChanged { ar.error = MapSaveTransaction.Failure.savedSessionChanged.localizedDescription }
            catch { ar.error = "Couldn't finish saving. Keep this session open to retry, or reopen the room to check its saved state. \(error.localizedDescription)" }
        }
    }
    private func reload() async {
        do { try await store.loadAnnotations(room); await ar.reload(store.annotations.filter { $0.room_id == room.id },store:store) } catch { ar.error = error.localizedDescription }
    }
}
