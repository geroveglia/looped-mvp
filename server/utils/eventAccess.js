// Who may open an event, and how much of it they get to see.
//
// Public events are open to any signed-in dancer. Private ones are invite-only:
// the document — and above all the invite code that unlocks it — belongs to the
// host and to the people who joined. Someone who *left* keeps read access on
// purpose: the party is part of their history, and looking back at it is the
// whole point of "mis eventos".

/**
 * @param {object} event    an Event document (or plain object)
 * @param {object} opts
 * @param {object|null} opts.membership  the asker's EventMember row, if any
 * @param {string|null} opts.userId      the asker
 */
function eventAccess(event, { membership = null, userId = null } = {}) {
    const isHost =
        Boolean(userId) && String(event.host_user_id) === String(userId);
    // A row exists for anyone who ever joined — leaving only stamps left_at.
    const hasJoined = Boolean(membership);
    const isActiveMember = hasJoined && !membership.left_at;
    const isPrivate = event.visibility === 'private';

    return {
        isHost,
        hasJoined,
        isActiveMember,
        allowed: !isPrivate || isHost || hasJoined,
        // The code lets its bearer walk in, so it only travels to people who
        // are still inside. Someone who left can read the event, not re-open it
        // for others.
        canSeeInviteCode: isHost || isActiveMember,
    };
}

/** The event as [access] permits seeing it. */
function viewEvent(event, access) {
    const plain =
        typeof event.toObject === 'function' ? event.toObject() : { ...event };
    if (!access.canSeeInviteCode) delete plain.invite_code;
    return plain;
}

module.exports = { eventAccess, viewEvent };
