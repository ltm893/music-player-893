import SwiftUI

struct LoginView: View {

    @ObservedObject var service: CloudService
    @Environment(\.dismiss) private var dismiss

    @State private var email        = ""
    @State private var password     = ""
    @State private var isSigningIn  = false
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        } else {
                            SecureField("Password", text: $password)
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if let error = service.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await signIn() }
                    } label: {
                        if isSigningIn {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty || isSigningIn)
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.navyBlue)
            .foregroundStyle(Color.navyBlue)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signIn() async {
        isSigningIn = true
        service.errorMessage = nil
        do {
            try await service.signIn(email: email, password: password)
            dismiss()
        } catch {
            service.errorMessage = error.localizedDescription
        }
        isSigningIn = false
    }
}
