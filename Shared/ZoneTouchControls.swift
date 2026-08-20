import SwiftUI

#if os(iOS)
  struct HoldButton: View {
    let title: String
    let action: ZoneInputRouter.Action
    let router: ZoneInputRouter
    var body: some View {
      Text(title).font(.headline).frame(width: 86, height: 64).background(.black.opacity(0.45))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.65))).contentShape(
          Rectangle()
        ).gesture(
          DragGesture(minimumDistance: 0).onChanged { _ in router.setTouch(action, pressed: true) }
            .onEnded { _ in router.setTouch(action, pressed: false) })
    }
  }
  struct ZoneTouchControls: View {
    let router: ZoneInputRouter
    var body: some View {
      HStack(alignment: .bottom) {
        HStack {
          HoldButton(title: "◀", action: .left, router: router)
          HoldButton(title: "▶", action: .right, router: router)
        }
        Spacer()
        VStack {
          HStack {
            HoldButton(title: "EQ +", action: .equipmentUp, router: router)
            HoldButton(title: "EQ −", action: .equipmentDown, router: router)
          }
          HStack {
            HoldButton(title: "THRUST", action: .thrust, router: router)
            HoldButton(title: "FIRE", action: .fire, router: router)
          }
        }
      }.padding(28).foregroundStyle(.white)
    }
  }
#endif
