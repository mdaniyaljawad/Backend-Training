#!/usr/bin/env bash
# Drives two real psql sessions (A = Alice, B = Bob) against the pgtrain container
# and interleaves their commands so the timing is deterministic.
# Usage: ./04_race.sh nolock | lock
MODE=${1:-nolock}
PSQL="docker exec -i pgtrain psql -U postgres -X"
D=$(mktemp -d); mkfifo $D/a $D/b
$PSQL < $D/a 2>&1 | sed -u 's/^/[A] /' &
$PSQL < $D/b 2>&1 | sed -u 's/^/[B] /' &
exec 3>$D/a 4>$D/b
A() { echo "$*" >&3; sleep ${W:-1}; }
B() { echo "$*" >&4; sleep ${W:-1}; }
P=$(docker exec -i pgtrain psql -U postgres -X -q -c "UPDATE offers SET status='open',accepted_by=NULL,accepted_at=NULL WHERE id=1")
echo "=== reset: offer 1 is open; Alice=buyer 1, Bob=buyer 2 ($MODE) ==="
A "\\pset footer off"; B "\\pset footer off"
if [ "$MODE" = nolock ]; then
  echo "--- both buyers open a transaction and read the offer"
  A "BEGIN;"; B "BEGIN;"
  A "SELECT id, status, accepted_by FROM offers WHERE id = 1;"
  B "SELECT id, status, accepted_by FROM offers WHERE id = 1;"
  echo "--- both saw 'open', so both decide to accept"
  A "UPDATE offers SET status='accepted', accepted_by=1, accepted_at=now() WHERE id=1;"
  B "UPDATE offers SET status='accepted', accepted_by=2, accepted_at=now() WHERE id=1;"
  echo "--- (B's UPDATE waited for A's row lock; now A commits)"
  A "COMMIT;"
  B "COMMIT;"
else
  echo "--- both buyers open a transaction and try to lock the offer row"
  A "BEGIN;"; B "BEGIN;"
  A "SELECT id, status, accepted_by FROM offers WHERE id = 1 FOR UPDATE;"
  echo "--- B asks for the same lock: it must wait (command is sent, no result yet)"
  W=2 B "SELECT id, status, accepted_by FROM offers WHERE id = 1 FOR UPDATE;"
  echo "--- third connection: what is B doing?"
  docker exec -i pgtrain psql -U postgres -X -c "SELECT pid, state, wait_event_type, wait_event, left(query,60) AS query FROM pg_stat_activity WHERE wait_event_type='Lock'"
  echo "--- A (holding the lock) accepts and commits"
  A "UPDATE offers SET status='accepted', accepted_by=1, accepted_at=now() WHERE id=1;"
  A "COMMIT;"
  echo "--- B is released and re-reads the committed row: status is no longer 'open'"
  sleep 1
  echo "--- app logic: status <> 'open' -> reject Bob, do not update"
  B "ROLLBACK;"
fi
echo "--- final state"
docker exec -i pgtrain psql -U postgres -X -c "SELECT id, status, accepted_by, (SELECT full_name FROM buyers WHERE id=accepted_by) AS winner FROM offers WHERE id=1"
exec 3>&- 4>&-; wait; rm -rf $D
