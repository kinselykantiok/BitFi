;; fee-hedge.clar
;; Uses an Oracle trait to verify current Bitcoin average fees

(use-trait fee-oracle-trait .oracle-trait.oracle-trait)

(define-constant ERR-NOT-FOUND u404)
(define-constant ERR-NOT-AUTH u403)
(define-constant ERR-INVALID u400)
(define-constant ERR-ALREADY-SETTLED u409)
(define-constant ERR-EXPIRED u408)
(define-constant ERR-ORACLE-NOT-APPROVED u406)
(define-constant ERR-ORACLE-STALE u410)
(define-constant ERR-NOT-SETTLEABLE u422)

(define-data-var next-id uint u1)
(define-data-var total-locked uint u0)
(define-data-var max-stale-blocks uint u144)
(define-data-var admin (optional principal) none)

(define-map positions 
    { id: uint } 
    { owner: principal, strike-fee: uint, amount-locked: uint, is-long: bool, created-at: uint, expires-at: uint, is-settled: bool, oracle: principal }
)

(define-map approved-oracles
    { oracle: principal }
    { approved: bool }
)

(define-private (is-approved-oracle (oracle principal))
    (default-to false (get approved (map-get? approved-oracles { oracle: oracle })))
)

(define-private (oracle-principal (oracle <fee-oracle-trait>))
    (contract-of oracle)
)

(define-private (calculate-payout (amount uint) (strike-fee uint) (current-fee uint) (is-long bool))
    (let (
        (fee-delta (if is-long
            (if (> current-fee strike-fee) (- current-fee strike-fee) u0)
            (if (> strike-fee current-fee) (- strike-fee current-fee) u0)
        ))
        (raw (if (> strike-fee u0) (/ (* amount fee-delta) strike-fee) u0))
    )
        (if (> raw amount) amount raw)
    )
)

(define-private (is-admin)
    (match (var-get admin)
        current-admin (is-eq tx-sender current-admin)
        false
    )
)

(define-read-only (get-position (id uint))
    (map-get? positions { id: id })
)

(define-read-only (get-admin)
    (var-get admin)
)

(define-read-only (get-total-locked)
    (var-get total-locked)
)

(define-read-only (get-max-stale-blocks)
    (var-get max-stale-blocks)
)

(define-public (set-oracle-approved (oracle principal) (approved bool))
    (begin
        (asserts! (is-admin) (err ERR-NOT-AUTH))
        (map-set approved-oracles { oracle: oracle } { approved: approved })
        (ok approved)
    )
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-none (var-get admin)) (err ERR-NOT-AUTH))
        (var-set admin (some new-admin))
        (ok new-admin)
    )
)

(define-public (set-max-stale-blocks (max-blocks uint))
    (begin
        (asserts! (is-admin) (err ERR-NOT-AUTH))
        (var-set max-stale-blocks max-blocks)
        (ok max-blocks)
    )
)

(define-public (create-hedge (amount uint) (strike-fee uint) (is-long bool) (expires-at uint) (oracle <fee-oracle-trait>))
    (let (
        (oracle-data (unwrap! (contract-call? oracle get-bitcoin-fee) (err ERR-INVALID)))
        (current-height (get current-height oracle-data))
        (last-updated (get last-updated oracle-data))
    )
        (begin
            (asserts! (> amount u0) (err ERR-INVALID))
            (asserts! (> strike-fee u0) (err ERR-INVALID))
            (asserts! (is-approved-oracle (oracle-principal oracle)) (err ERR-ORACLE-NOT-APPROVED))
            (asserts! (>= current-height last-updated) (err ERR-ORACLE-STALE))
            (asserts! (<= (- current-height last-updated) (var-get max-stale-blocks)) (err ERR-ORACLE-STALE))
            (asserts! (> expires-at current-height) (err ERR-EXPIRED))
            (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
            (let ((id (var-get next-id)))
                (map-set positions { id: id } {
                    owner: tx-sender,
                    strike-fee: strike-fee,
                    amount-locked: amount,
                    is-long: is-long,
                    created-at: current-height,
                    expires-at: expires-at,
                    is-settled: false,
                    oracle: (oracle-principal oracle)
                })
                (var-set next-id (+ id u1))
                (var-set total-locked (+ (var-get total-locked) amount))
                (ok id)
            )
        )
    )
)

(define-public (settle-hedge (id uint) (oracle <fee-oracle-trait>))
    (let (
        (position (unwrap! (map-get? positions { id: id }) (err ERR-NOT-FOUND)))
        (oracle-data (unwrap! (contract-call? oracle get-bitcoin-fee) (err ERR-INVALID)))
        (current-fee (get fee oracle-data))
        (last-updated (get last-updated oracle-data))
        (current-height (get current-height oracle-data))
    )
        (begin
            (asserts! (not (get is-settled position)) (err ERR-ALREADY-SETTLED))
            (asserts! (is-approved-oracle (oracle-principal oracle)) (err ERR-ORACLE-NOT-APPROVED))
            (asserts! (is-eq (get oracle position) (oracle-principal oracle)) (err ERR-ORACLE-NOT-APPROVED))
            (asserts! (>= current-height last-updated) (err ERR-ORACLE-STALE))
            (asserts! (<= (- current-height last-updated) (var-get max-stale-blocks)) (err ERR-ORACLE-STALE))
            (asserts! (<= current-height (get expires-at position)) (err ERR-EXPIRED))
            (let ((payout (calculate-payout (get amount-locked position) (get strike-fee position) current-fee (get is-long position))))
                (asserts! (> payout u0) (err ERR-NOT-SETTLEABLE))
                (try! (as-contract (stx-transfer? payout tx-sender (get owner position))))
                (map-set positions { id: id } (merge position { is-settled: true }))
                (var-set total-locked (- (var-get total-locked) (get amount-locked position)))
                (ok payout)
            )
        )
    )
)

(define-public (expire-hedge (id uint) (oracle <fee-oracle-trait>))
    (let (
        (position (unwrap! (map-get? positions { id: id }) (err ERR-NOT-FOUND)))
        (oracle-data (unwrap! (contract-call? oracle get-bitcoin-fee) (err ERR-INVALID)))
        (current-height (get current-height oracle-data))
    )
        (begin
            (asserts! (not (get is-settled position)) (err ERR-ALREADY-SETTLED))
            (asserts! (is-approved-oracle (oracle-principal oracle)) (err ERR-ORACLE-NOT-APPROVED))
            (asserts! (is-eq (get oracle position) (oracle-principal oracle)) (err ERR-ORACLE-NOT-APPROVED))
            (asserts! (> current-height (get expires-at position)) (err ERR-EXPIRED))
            (try! (as-contract (stx-transfer? (get amount-locked position) tx-sender (get owner position))))
            (map-set positions { id: id } (merge position { is-settled: true }))
            (var-set total-locked (- (var-get total-locked) (get amount-locked position)))
            (ok true)
        )
    )
)
