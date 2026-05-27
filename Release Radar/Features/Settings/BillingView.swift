import SwiftUI

struct BillingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @State private var status: BillingStatus?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancelling = false

    var body: some View {
        Form {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            } else if let status {
                Section("Current plan") {
                    LabeledContent("Tier", value: status.tier.capitalized)
                    if let s = status.status { LabeledContent("Status", value: s.capitalized) }
                    if status.cancelAtPeriodEnd == true, let until = status.currentPeriodEnd {
                        LabeledContent("Cancels", value: until)
                    } else if let until = status.currentPeriodEnd {
                        LabeledContent("Renews", value: until)
                    }
                }

                if status.tier == "free" {
                    Section("Upgrade") {
                        Button("Subscribe monthly") {
                            Task { await checkout(interval: "monthly") }
                        }
                        Button("Subscribe yearly") {
                            Task { await checkout(interval: "yearly") }
                        }
                    }
                } else {
                    Section("Manage") {
                        Button("Open Stripe portal") {
                            Task { await portal() }
                        }
                        if status.cancelAtPeriodEnd != true && status.tier != "admin" {
                            Button(cancelling ? "Cancelling…" : "Cancel subscription", role: .destructive) {
                                Task { await cancel() }
                            }
                            .disabled(cancelling)
                        }
                    }
                }
            }
        }
        .navigationTitle("Billing")
        .task { await load() }
    }

    private func load() async {
        isLoading = true; defer { isLoading = false }
        do {
            status = try await env.apiClient.billingStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func checkout(interval: String) async {
        do {
            let response = try await env.apiClient.billingCreateCheckoutSession(interval: interval)
            if let url = URL(string: response.url) { openURL(url) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func portal() async {
        do {
            let response = try await env.apiClient.billingCreatePortalSession()
            if let url = URL(string: response.url) { openURL(url) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func cancel() async {
        cancelling = true; defer { cancelling = false }
        do {
            _ = try await env.apiClient.billingCancel()
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
