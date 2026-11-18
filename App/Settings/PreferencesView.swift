import CoachCore
import SwiftUI

/// Settings → Preferences (N3, ease budget §3): every onboarding module with
/// its current value as the subtitle (`prefs.module.*`). A module opens a
/// standard form; changes save as they are made, with no Save button, and
/// start tomorrow (`ProfileStore.save(_:effectiveFrom:)`), so today's plan
/// and alarms stay as they are.
struct PreferencesView: View {
    let programme: Programme
    /// Ingredient names, to pick dislikes from.
    let foods: [String]
    /// N4: the shops offered and the office walk that applies until answered.
    var shops: [NutritionContent.Shop.Option] = []
    var defaultLunchWalk = 10
    /// Called with every change; the caller stores it from tomorrow.
    var onChange: (Profile.Preferences) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Profile

    /// Onboarding's modules, less the start date (only the app moves the programme), plus foods.
    static let rows: [ProfileRow] = [.you, .goal, .hurts, .sleep, .work, .office, .fixed,
                                     .kit, .longest, .cues, .checkIn, .food, .shop, .officeLunch]

    init(profile: Profile, programme: Programme, foods: [String],
         shops: [NutritionContent.Shop.Option] = [], defaultLunchWalk: Int = 10,
         onChange: @escaping (Profile.Preferences) -> Void) {
        self.shops = shops
        self.defaultLunchWalk = defaultLunchWalk
        var draft = profile
        draft.preferences = profile.latestPreferences // an edit already waiting for tomorrow
        _draft = State(initialValue: draft)
        self.programme = programme
        self.foods = foods
        self.onChange = onChange
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Self.rows) { row in
                        let rows = helper(row)
                        if rows.hasEditor(row) {
                            NavigationLink {
                                ModuleForm(row: row, title: rows.label(row), editor: rows, search: row == .food)
                            } label: {
                                subtitleRow(rows, row)
                            }
                            .accessibilityIdentifier("prefs.module.\(row.rawValue)")
                        } else {
                            subtitleRow(rows, row)
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("prefs.module.\(row.rawValue)")
                        }
                    }
                } footer: {
                    Text("Changes start tomorrow.")
                        .accessibilityIdentifier("prefs.fromTomorrow")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("prefs.done")
                }
            }
            .onChange(of: draft.preferences) { _, edited in onChange(edited) }
        }
    }

    private func helper(_ row: ProfileRow) -> ProfileRowView {
        ProfileRowView(profile: $draft, programme: programme, row: row, editing: .constant(nil),
                       idPrefix: "prefs", showsGuess: false, dislikeOptions: foods,
                       shops: shops, defaultLunchWalk: defaultLunchWalk)
    }

    private func subtitleRow(_ rows: ProfileRowView, _ row: ProfileRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rows.label(row)).foregroundStyle(.primary)
            Text(rows.value(row)).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// One module as a standard form, edited in place.
private struct ModuleForm: View {
    let row: ProfileRow
    let title: String
    let editor: ProfileRowView
    /// Foods get a search field over the list.
    let search: Bool
    @State private var term = ""

    var body: some View {
        if search {
            Form { editor.dislikes(search: $term) }
                .searchable(text: $term, prompt: "Search foods")
                .navigationTitle(title)
        } else {
            Form { editor.editor(row) }
                .navigationTitle(title)
        }
    }
}
