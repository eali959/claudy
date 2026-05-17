import SwiftUI

// MARK: - Claudy2DFaceOverlay
//
// Hybrid-character face layer.
//
// The 3-D body is rendered by ClaudyRealityView (RealityKit USDZ — body, arms,
// legs as separate meshes painted flat #C15F3C).  The face — eyes, mouth,
// blinks, expressions, blush — stays in pure SwiftUI so we keep the highly
// expressive Pixar-style 2-D face rig (Manager-driven via AnimationConfig)
// without trying to bake it into a 3-D model.
//
// This view is intentionally tiny: it just instantiates ClaudyCharacterView in
// `faceOnly` mode, which short-circuits the whole 2-D body/arm/foot pipeline
// and renders only the face primitives.  Position, gestures, drag, and
// animation transforms are all owned by the 3-D layer underneath — this view
// is hit-testing-disabled so taps fall through to the RealityKit shim.
//
// Usage:
//   ZStack {
//       ClaudyRealityView(...)
//       Claudy2DFaceOverlay(
//           animationState:  vm.animationState,
//           isBlinking:      vm.isBlinking,
//           irisOffset:      vm.irisOffset,
//           tickleIntensity: vm.tickleIntensity,
//           danceMove:       vm.danceModeManager.currentMove
//       )
//   }
//
// The face is rendered at the same logical character size as the 2-D mode so
// eye / mouth scale matches.  An offset shifts it up to the head region of
// the 3-D body — tweak `headOffsetY` to align with the new model.
struct Claudy2DFaceOverlay: View {

    let animationState:  CharacterAnimationState
    var isBlinking:      Bool             = false
    var irisOffset:      CGPoint          = .zero
    var tickleIntensity: TickleIntensity  = .none
    var danceMove:       DanceMove        = .groove
    var characterScale:  CGFloat          = 0.8

    /// Vertical offset (in 2-D points) from the centre of the character frame
    /// up to where the face should sit on the 3-D body's "head" region.
    /// Default 0: the face's intrinsic `eyesOffsetY` / `mouthOffsetY` already
    /// position eyes and mouth in the upper-centre of the 130×150 frame,
    /// which lines up with the head region of the 3-D body when it fills the
    /// frame. Nudge negative if the face sits too low, positive if too high.
    var headOffsetY: CGFloat = 0

    var body: some View {
        ClaudyCharacterView(
            animationState:  animationState,
            isBlinking:      isBlinking,
            irisOffset:      irisOffset,
            tickleIntensity: tickleIntensity,
            danceMove:       danceMove,
            accessory:       .none,           // accessories live on 3-D body if at all
            characterScale:  characterScale,
            faceOnly:        true
        )
        .frame(width: CharacterGeometry.characterFrameWidth,
               height: CharacterGeometry.characterFrameHeight)
        .offset(y: headOffsetY)
        .allowsHitTesting(false)              // taps pass through to ClickableRealityShim
        .accessibilityHidden(true)            // 3-D layer owns the accessibility label
    }
}
