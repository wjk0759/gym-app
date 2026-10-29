import SwiftUI

/// A button that owns its own sheet presentation state.
///
/// Use this for a sheet trigger inside a large screen. Keeping the boolean
/// here means opening the sheet only invalidates this small wrapper instead of
/// recomputing the whole screen (and its calendar/lists) during presentation.
struct SheetPresentingButton<Label: View, SheetContent: View>: View {
    @State private var isPresented = false

    private let label: Label
    private let sheetContent: SheetContent

    init(
        @ViewBuilder label: () -> Label,
        @ViewBuilder sheet: () -> SheetContent
    ) {
        self.label = label()
        self.sheetContent = sheet()
    }

    var body: some View {
        Button {
            Haptics.tap()
            isPresented = true
        } label: {
            label
        }
        .buttonStyle(SubtlePressStyle(scale: 0.98))
        .sheet(isPresented: $isPresented) {
            sheetContent
        }
    }
}
