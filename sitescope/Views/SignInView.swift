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
    /// Supabase's default minimum; the server checks it again on sign-up. Signing in accepts any length, so older
    /// accounts are never locked out.
    static let minimumPasswordLength = 6
    @State private var mode = Mode.signIn
    @State private var email = ""
    @State private var password = ""
    @State private var notice: String?
    @State private var resetSent = false
    @FocusState private var focus: Field?

    private var canSubmit: Bool {
        let passwordOK = mode == .register ? password.count >= Self.minimumPasswordLength : !password.isEmpty
        return email.contains("@") && passwordOK && store.hasBackend && !store.busy
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sign in or create an account", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if let notice {
                    Section {
                        Label(notice, systemImage: "envelope.badge").foregroundStyle(.tint)
                    }
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
                    if mode == .register {
                        Text(
                            "Use at least \(Self.minimumPasswordLength) characters. You’ll get an email to confirm the account."
                        )
                    }
                }
                Section {
                    Button(action: submit) {
                        Text(mode.rawValue).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canSubmit)
                    .accessibilityIdentifier("auth.submit")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    if mode == .signIn {
                        Button("Forgot Password?") { sendReset() }
                            .frame(maxWidth: .infinity)
                            .disabled(!store.hasBackend || store.busy)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("auth.forgot")
                    }
                }
                if !store.hasBackend {
                    Section {
                        Label("Sign-in isn’t available in this build", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(Color("Warning"))
                    } footer: {
                        #if DEBUG
                            Text("Add the Supabase URL and publishable key to Secrets.xcconfig and build again.")
                        #endif
                    }
                }
            }
            .navigationTitle("sitescope")
            .onAppear { if email.isEmpty { focus = .email } }
            .alert("Check Your Email", isPresented: $resetSent) {
                Button("OK") {}
            } message: {
                Text("If an account uses \(email), it gets a link to choose a new password.")
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let register = mode == .register
        notice = nil
        store.run {
            let active = try await store.signIn(email: email, password: password, register: register)
            if !active {
                mode = .signIn
                notice = "Check your email to confirm your account, then sign in."
            }
        }
    }

    private func sendReset() {
        store.run {
            try await store.requestPasswordReset(email: email)
            resetSent = true
        }
    }
}
