import SwiftUI

struct TrackingTipsView: View {
    var body: some View {
        List {
            Section { Label("No LiDAR required",systemImage:"camera.viewfinder").font(.headline)
                Text("sitescope uses the camera and motion sensors to map visual details. Good lighting and overlapping viewpoints help it find the room again.") }
            Section("1 · Find detail") { Text("Include corners, door frames and textured objects. Blank walls, mirrors, glare and very dark rooms are difficult to track.") }
            Section("2 · Move gently") { Text("Walk slowly and look sideways as well as forward. Pause after quick turns. Moving to another position provides more information than rotating in place.") }
            Section("3 · Connect the room") { Text("Scan from several positions and all directions, then look back at details you have already captured. The progress checks guide the scan; they do not guarantee complete coverage.") }
            Section("4 · Place and recheck") { Text("Wait for a detected surface to settle, check the highlighted plane and lock the view before drawing. Recheck the saved drawing from another angle. If detection is poor, use a measured distance explicitly.") }
            Section("Returning later") { Text("Look at details seen during the original scan, from overlapping viewpoints. Changes in lighting or furniture can affect recognition. Drawings remain hidden until the room is aligned; tasks are always available in the list.") }
        }.navigationTitle("Scanning tips").navigationBarTitleDisplayMode(.inline)
    }
}
