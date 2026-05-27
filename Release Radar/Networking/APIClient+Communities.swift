import Foundation

/// Endpoints under `/communities` — browse / mine / create / detail,
/// membership, invitations, media (titles), posts, and replies. Mirrors
/// the backend community router 1:1 so each screen has a single method
/// to call.
extension APIClient {

    // MARK: - Discovery & CRUD

    /// GET /communities — paginated browse with optional `q` filter.
    /// Backend returns the array directly (no envelope).
    func communitiesBrowse(query: String? = nil, limit: Int = 30, offset: Int = 0) async throws -> [Community] {
        var items: [URLQueryItem] = [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ]
        if let query, !query.isEmpty {
            items.append(.init(name: "q", value: query))
        }
        // Note: no trailing slash — the backend's index handler is mounted
        // at `""`, so `/communities/` 307-redirects to `/communities` and
        // the Authorization header is dropped along the way.
        return try await get("/communities", query: items)
    }

    /// GET /communities/mine — the user's joined communities.
    func communitiesMine() async throws -> [Community] {
        try await get("/communities/mine")
    }

    /// POST /communities — create a new community.
    func communityCreate(
        name: String,
        description: String?,
        visibility: String,
        bannerColor: String?
    ) async throws -> Community {
        try await sendDecoded(
            "/communities",
            method: "POST",
            body: CommunityCreateBody(
                name: name,
                description: description,
                visibility: visibility,
                banner_color: bannerColor
            )
        )
    }

    /// GET /communities/{slug} — detail by slug.
    func community(slug: String) async throws -> Community {
        try await get("/communities/\(slug)")
    }

    /// PATCH /communities/{id} — owner/admin edits.
    @discardableResult
    func communityUpdate(
        id: Int,
        name: String? = nil,
        description: String? = nil,
        visibility: String? = nil,
        bannerColor: String? = nil,
        membersCanEditMedia: Bool? = nil
    ) async throws -> Community {
        try await sendDecoded(
            "/communities/\(id)",
            method: "PATCH",
            body: CommunityUpdateBody(
                name: name,
                description: description,
                visibility: visibility,
                banner_color: bannerColor,
                members_can_edit_media: membersCanEditMedia
            )
        )
    }

    /// DELETE /communities/{id} — owner only.
    @discardableResult
    func communityDelete(id: Int) async throws -> Data {
        try await send("/communities/\(id)", method: "DELETE")
    }

    // MARK: - Membership

    @discardableResult
    func communityJoin(id: Int) async throws -> CommunityJoinResponse {
        try await sendDecoded("/communities/\(id)/join", method: "POST")
    }

    @discardableResult
    func communityLeave(id: Int) async throws -> CommunityLeaveResponse {
        try await sendDecoded("/communities/\(id)/leave", method: "POST")
    }

    func communityMembers(id: Int) async throws -> [CommunityMember] {
        try await get("/communities/\(id)/members")
    }

    /// POST /communities/{id}/members/invite — also triggers the
    /// `community_invite` push notification on the backend.
    @discardableResult
    func communityInvite(id: Int, username: String) async throws -> CommunityInvitationStub {
        try await sendDecoded(
            "/communities/\(id)/members/invite",
            method: "POST",
            body: CommunityInviteBody(username: username)
        )
    }

    @discardableResult
    func communityRemoveMember(id: Int, userID: String) async throws -> Data {
        try await send("/communities/\(id)/members/\(userID)", method: "DELETE")
    }

    private struct CommunityRoleBody: Encodable { let role: String }

    @discardableResult
    func communitySetRole(id: Int, userID: String, role: String) async throws -> Data {
        try await send(
            "/communities/\(id)/members/\(userID)/role",
            method: "PATCH",
            body: CommunityRoleBody(role: role)
        )
    }

    // MARK: - Invitations

    /// GET /communities/invitations/mine — the user's pending invitations.
    func communityInvitationsMine() async throws -> [CommunityInvitation] {
        try await get("/communities/invitations/mine")
    }

    @discardableResult
    func communityRespondToInvitation(id: Int, accept: Bool) async throws -> CommunityInvitationRespondResponse {
        try await sendDecoded(
            "/communities/invitations/\(id)/respond",
            method: "POST",
            body: CommunityInvitationRespondBody(accept: accept)
        )
    }

    // MARK: - Media

    func communityMedia(id: Int) async throws -> CommunityMediaResponse {
        try await get("/communities/\(id)/media")
    }

    @discardableResult
    func communityAddMedia(id: Int, contentType: String, contentID: Int) async throws -> Data {
        try await send(
            "/communities/\(id)/media",
            method: "POST",
            body: CommunityMediaAddBody(content_type: contentType, content_id: contentID)
        )
    }

    @discardableResult
    func communityRemoveMedia(id: Int, mediaID: Int) async throws -> Data {
        try await send("/communities/\(id)/media/\(mediaID)", method: "DELETE")
    }

    // MARK: - Posts

    func communityPosts(id: Int, limit: Int = 30, offset: Int = 0) async throws -> [CommunityPost] {
        try await get("/communities/\(id)/posts", query: [
            .init(name: "limit", value: "\(limit)"),
            .init(name: "offset", value: "\(offset)")
        ])
    }

    @discardableResult
    func communityCreatePost(id: Int, title: String?, body: String) async throws -> CommunityPost {
        try await sendDecoded(
            "/communities/\(id)/posts",
            method: "POST",
            body: CommunityPostCreateBody(title: title, body: body)
        )
    }

    func communityPostDetail(postID: Int) async throws -> CommunityPostDetail {
        try await get("/communities/posts/\(postID)")
    }

    @discardableResult
    func communityDeletePost(postID: Int) async throws -> Data {
        try await send("/communities/posts/\(postID)", method: "DELETE")
    }

    @discardableResult
    func communityCreateReply(postID: Int, body: String) async throws -> CommunityReply {
        try await sendDecoded(
            "/communities/posts/\(postID)/replies",
            method: "POST",
            body: CommunityReplyCreateBody(body: body)
        )
    }

    @discardableResult
    func communityDeleteReply(replyID: Int) async throws -> Data {
        try await send("/communities/replies/\(replyID)", method: "DELETE")
    }

    @discardableResult
    func communityLikePost(postID: Int) async throws -> CommunityLikeResponse {
        try await sendDecoded("/communities/posts/\(postID)/like", method: "POST")
    }

    @discardableResult
    func communityLikeReply(replyID: Int) async throws -> CommunityLikeResponse {
        try await sendDecoded("/communities/replies/\(replyID)/like", method: "POST")
    }
}
