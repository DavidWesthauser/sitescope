import SwiftUI

/// Sign-in and registration. Nothing else is reachable until someone is signed in; afterwards the app also works
/// offline with the saved session.
struct SignInView: View {
    @EnvironmentObject var store: Store
    private enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case register = "Create Account"
        var id: Self { self }
    }
    private enum Field { case email, password }
    /// Supabase's default minimum; the server checks it again on sign-up.
    static let minimumPasswordLength = 6
    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var notice: String?
    @FocusState private var focus: Field?

    private var canSubmit: Bool {
        email.contains("@") && password.count >= Self.minimumPasswordLength && store.hasBackend && !store.busy
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.username).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focus, equals: .email).submitLabel(.next)
                        .onSubmit { focus = .password }
                        .accessibilityIdentifier("auth.email")
                    SecureField("Password", text: $password)
                        .textContentType(mode == .register ? .newPassword : .password)
                        .focused($focus, equals: .password).submitLabel(.go)
                        .onSubmit(submit)
                        .accessibilityIdentifier("auth.password")
                } footer: {
                    Text(
                        mode == .register
                            ? "Use at least \(Self.minimumPasswordLength) characters. You’ll get an email to confirm the account."
                            : "Sign in to see your projects and the ones shared with you.")
                }
                Section {
                    Button(mode.rawValue, action: submit)
                        .frame(maxWidth: .infinity)
                        .disabled(!canSubmit)
                        .accessibilityIdentifier("auth.submit")
                } footer: {
                    if let notice { Text(notice) }
                }
                if !store.hasBackend {
                    Section {
                        Label("No server configured", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color("Warning"))
                    } footer: {
                        Text("Add the Supabase URL and publishable key to Secrets.xcconfig and build again.")
                    }
                }
            }
            .navigationTitle("sitescope")
            .onChange(of: mode) { _, _ in notice = nil }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let register = mode == .register
        store.run {
            let active = try await store.signIn(email: email, password: password, register: register)
            if !active {
                notice = "Check your email to confirm your account, then sign in."
                mode = .signIn
            }
        }
    }
}
