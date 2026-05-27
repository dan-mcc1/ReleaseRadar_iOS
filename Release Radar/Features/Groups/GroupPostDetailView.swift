import SwiftUI

/// Post + threaded replies. Renders the parent post in full, followed by
/// each reply card and an inline reply composer for members.
struct GroupPostDetailView: View {
    let communitySlug: String
    let postID: Int

    @Environment(AppEnvironment.self) private var env
    @State private var detail: CommunityPostDetail?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var replyText: String = ""
    @State private var isPosting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading && detail == nil {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 64)
                } else if let error = errorMessage, detail == nil {
                    InlineErrorBanner(message: error) { Task { await load() } }
                        .padding(.horizontal, 16)
                } else if let detail {
                    postBlock(post: detail.post)
                        .padding(.horizontal, 16)

                    if !detail.replies.isEmpty {
                        SectionTitle("\(detail.replies.count)", accent: "replies")
                            .padding(.horizontal, 16)
                        LazyVStack(spacing: 8) {
                            ForEach(detail.replies) { reply in
                                replyBlock(reply: reply)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .pageBackground()
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { composer }
        .task { await load() }
    }

    // MARK: - Blocks

    private func postBlock(post: CommunityPost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                AvatarView(username: post.user?.username, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(post.user?.label ?? "—")
                        .font(BrandFont.sans(13, weight: .semibold))
                        .foregroundStyle(BrandTheme.text)
                    if let created = post.createdAt, let ago = TimeAgo.format(created) {
                        Text(ago).font(BrandFont.mono(10)).foregroundStyle(BrandTheme.textDim)
                    }
                }
                Spacer()
            }
            if let title = post.title, !title.isEmpty {
                Text(title)
                    .font(BrandFont.serif(22))
                    .foregroundStyle(BrandTheme.text)
            }
            Text(post.body)
                .font(BrandFont.sans(14))
                .foregroundStyle(BrandTheme.text)
                .multilineTextAlignment(.leading)

            HStack(spacing: 16) {
                Button {
                    Task { await toggleLikePost() }
                } label: {
                    Label("\(post.likeCount)", systemImage: post.viewerLiked ? "heart.fill" : "heart")
                        .font(BrandFont.mono(12, weight: .semibold))
                        .foregroundStyle(post.viewerLiked ? BrandTheme.primaryText : BrandTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(BrandTheme.border, lineWidth: 1))
    }

    private func replyBlock(reply: CommunityReply) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                AvatarView(username: reply.user?.username, size: 26)
                Text(reply.user?.label ?? "—")
                    .font(BrandFont.sans(12, weight: .semibold))
                    .foregroundStyle(BrandTheme.text)
                Spacer()
                if let created = reply.createdAt, let ago = TimeAgo.format(created) {
                    Text(ago).font(BrandFont.mono(10)).foregroundStyle(BrandTheme.textDim)
                }
            }
            Text(reply.body)
                .font(BrandFont.sans(13))
                .foregroundStyle(BrandTheme.text)
            HStack {
                Button {
                    Task { await toggleLikeReply(reply) }
                } label: {
                    Label("\(reply.likeCount)", systemImage: reply.viewerLiked ? "heart.fill" : "heart")
                        .font(BrandFont.mono(11, weight: .medium))
                        .foregroundStyle(reply.viewerLiked ? BrandTheme.primaryText : BrandTheme.textMuted)
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(10)
        .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrandTheme.border, lineWidth: 1))
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 0) {
            Divider().background(BrandTheme.border)
            HStack(spacing: 8) {
                TextField("Reply…", text: $replyText, axis: .vertical)
                    .font(BrandFont.sans(13))
                    .padding(10)
                    .background(BrandTheme.surface, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(BrandTheme.border, lineWidth: 1))
                    .lineLimit(1...4)
                Button {
                    Task { await submitReply() }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? BrandTheme.textMuted : .white)
                        .frame(width: 40, height: 40)
                        .background(
                            replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? BrandTheme.surface2 : BrandTheme.primary,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
                .disabled(isPosting || replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .background(BrandTheme.bg)
        }
    }

    // MARK: - Actions

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await env.apiClient.communityPostDetail(postID: postID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitReply() async {
        let trimmed = replyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isPosting else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            let reply = try await env.apiClient.communityCreateReply(postID: postID, body: trimmed)
            detail?.appendReply(reply)
            replyText = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleLikePost() async {
        do {
            let result = try await env.apiClient.communityLikePost(postID: postID)
            detail?.applyPostLike(result)
        } catch {
            // ignore
        }
    }

    private func toggleLikeReply(_ reply: CommunityReply) async {
        do {
            let result = try await env.apiClient.communityLikeReply(replyID: reply.id)
            detail?.applyReplyLike(replyID: reply.id, result: result)
        } catch {
            // ignore
        }
    }
}

// MARK: - Mutation helpers
//
// `CommunityPostDetail` / `CommunityPost` / `CommunityReply` are pure
// Decodable structs (no synthesised mutators), so do JSON round-trips for
// surgical mutations after a like / new reply.

private extension CommunityPostDetail {
    mutating func appendReply(_ reply: CommunityReply) {
        self = CommunityPostDetail(post: post.with(replyCountDelta: 1), replies: replies + [reply])
    }

    mutating func applyPostLike(_ result: CommunityLikeResponse) {
        self = CommunityPostDetail(post: post.applying(like: result), replies: replies)
    }

    mutating func applyReplyLike(replyID: Int, result: CommunityLikeResponse) {
        let updated = replies.map { reply in
            reply.id == replyID ? reply.applying(like: result) : reply
        }
        self = CommunityPostDetail(post: post, replies: updated)
    }
}

private extension CommunityPost {
    func with(replyCountDelta delta: Int) -> CommunityPost {
        CommunityPost(
            id: id,
            communityId: communityId,
            title: title,
            body: body,
            replyCount: max(0, replyCount + delta),
            likeCount: likeCount,
            viewerLiked: viewerLiked,
            editedAt: editedAt,
            createdAt: createdAt,
            user: user
        )
    }

    func applying(like: CommunityLikeResponse) -> CommunityPost {
        CommunityPost(
            id: id,
            communityId: communityId,
            title: title,
            body: body,
            replyCount: replyCount,
            likeCount: like.likeCount,
            viewerLiked: like.liked,
            editedAt: editedAt,
            createdAt: createdAt,
            user: user
        )
    }
}

private extension CommunityReply {
    func applying(like: CommunityLikeResponse) -> CommunityReply {
        CommunityReply(
            id: id,
            postId: postId,
            body: body,
            likeCount: like.likeCount,
            viewerLiked: like.liked,
            editedAt: editedAt,
            createdAt: createdAt,
            user: user
        )
    }
}
