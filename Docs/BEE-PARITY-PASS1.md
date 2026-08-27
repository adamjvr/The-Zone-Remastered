# Bee Parity Pass 1 — Requester Quota Lifetime Semantics

One behavior changes: destroying a Bee no longer refunds the requesting Mother's Bee-request quota.

Recovered behavior indicates requester field `+76` is incremented on a successful request and is not decremented by Bee cleanup. The existing portable code used a reverse requester link to decrement `bee_request_count` on Bee destruction, allowing the same Mother to request another Bee after every kill when the per-wave limit is one.

Pass 1 removes only that refund. Donor `bee_out_count` cleanup remains where it was before this pass; donor timing is reserved for Pass 2.

Expected Professional Wave 2 behavior: Mother A may successfully request one Bee; killing that Bee does not restore Mother A's quota. Mother B has its own independent quota and can still request one Bee when attacked.

Acceptance: deterministic tests pass, macOS gameplay is otherwise unchanged, and repeatedly attacking the same Mother can no longer create an endless sequence of replacement Bees.
