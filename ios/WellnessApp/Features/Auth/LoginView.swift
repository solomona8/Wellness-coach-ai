import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingForgotPassword = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo/Header
                    VStack(spacing: 12) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.linearGradient(
                                colors: [.pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))

                        Text("Wellness Coach AI")
                            .font(.largeTitle)
                            .bold()

                        Text("Your AI-powered health companion")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)

                    // Form
                    VStack(spacing: 16) {
                        // Email field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            TextField("Enter your email", text: $email)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                        }

                        // Password field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            SecureField("Enter your password", text: $password)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Forgot password (only for sign in)
                        if !isSignUp {
                            Button {
                                showingForgotPassword = true
                            } label: {
                                Text("Forgot password?")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal)

                    // Action buttons
                    VStack(spacing: 16) {
                        // Primary button
                        Button {
                            Task {
                                await authenticate()
                            }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .bold()
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFormValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!isFormValid || isLoading)

                        // Toggle sign in/sign up
                        Button {
                            withAnimation {
                                isSignUp.toggle()
                                errorMessage = nil
                            }
                        } label: {
                            if isSignUp {
                                Text("Already have an account? **Sign In**")
                            } else {
                                Text("Don't have an account? **Sign Up**")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
            .alert("Reset Password", isPresented: $showingForgotPassword) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                Button("Cancel", role: .cancel) {}
                Button("Send Reset Link") {
                    Task {
                        await resetPassword()
                    }
                }
            } message: {
                Text("Enter your email address and we'll send you a link to reset your password.")
            }
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
    }

    private func authenticate() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await authManager.signUp(email: email, password: password)
            } else {
                try await authManager.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func resetPassword() async {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address"
            return
        }

        do {
            try await authManager.resetPassword(email: email)
            errorMessage = "Password reset email sent!"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
