;; oracle-trait.clar
;; Interface for trusted BTC fee oracle contracts.

(define-trait oracle-trait
    (
        (get-bitcoin-fee () (response (tuple (fee uint) (last-updated uint) (current-height uint)) uint))
    )
)
