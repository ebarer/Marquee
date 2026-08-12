//
//  WatchedDatePicker.swift
//  MovieTracker
//

import SwiftUI

/// The shared date-picker sheet behind the watched-date buttons: "Today" plus one optional
/// quick-set (release / last episode date). Persistence is delegated via `onChange`.
struct WatchedDatePicker: View {
    let tint: Color
    var font: Font? = nil
    let quickSetTitle: String?
    let quickSetDate: Date?
    let onChange: (Date) -> Void

    @State private var date: Date
    @State private var showPicker = false

    init(initialDate: Date, tint: Color, font: Font? = nil,
         quickSetTitle: String? = nil, quickSetDate: Date? = nil,
         onChange: @escaping (Date) -> Void) {
        self.tint = tint
        self.font = font
        self.quickSetTitle = quickSetTitle
        self.quickSetDate = quickSetDate
        self.onChange = onChange
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        Button { showPicker = true } label: {
            label
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker("Date Watched", selection: $date, in: ...Date(),
                           displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(tint)
                    .padding(.horizontal)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(role: .confirm) { showPicker = false }
                        }
                        ToolbarItemGroup(placement: .topBarLeading) {
                            Button("Today") { date = Date() }
                            if let quickSetTitle, let quickSetDate, quickSetDate <= Date() {
                                Button(quickSetTitle) { date = quickSetDate }
                            }
                        }
                    }
                    .onChange(of: date) { _, newValue in onChange(newValue) }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    // Applies `font` only when supplied, so callers relying on an ambient font (the
    // metadata cell's size-14) keep inheriting it.
    @ViewBuilder
    private var label: some View {
        let text = Text(date, format: .dateTime.month(.abbreviated).day().year())
            .foregroundStyle(tint)
        if let font {
            text.font(font).contentShape(Rectangle())
        } else {
            text.contentShape(Rectangle())
        }
    }
}

#Preview {
    WatchedDatePicker(initialDate: Date(), tint: .appAccent,
                      quickSetTitle: "Release Date", quickSetDate: Date()) { _ in }
        .padding()
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
}
