;; simple-oracle.clar
;; Basic oracle for local dev; admin updates fee and height manually.

(impl-trait .oracle-trait.oracle-trait)

(define-constant ERR-NOT-AUTH u403)
(define-constant ERR-INVALID u400)

(define-data-var admin (optional principal) none)
(define-data-var fee uint u0)
(define-data-var last-updated uint u0)
(define-data-var current-height uint u0)

(define-private (is-admin)
    (match (var-get admin)
        current-admin (is-eq tx-sender current-admin)
        false
    )
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-none (var-get admin)) (err ERR-NOT-AUTH))
        (var-set admin (some new-admin))
        (ok new-admin)
    )
)

(define-public (update-fee (new-fee uint) (new-height uint))
    (begin
        (asserts! (is-admin) (err ERR-NOT-AUTH))
        (asserts! (>= new-height (var-get current-height)) (err ERR-INVALID))
        (var-set fee new-fee)
        (var-set current-height new-height)
        (var-set last-updated new-height)
        (ok new-fee)
    )
)

(define-read-only (get-bitcoin-fee)
    (ok {
        fee: (var-get fee),
        last-updated: (var-get last-updated),
        current-height: (var-get current-height)
    })
)

(define-read-only (get-admin)
    (var-get admin)
)
