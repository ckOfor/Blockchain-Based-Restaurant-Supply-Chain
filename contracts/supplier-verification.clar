;; Supplier Verification Contract
;; This contract validates legitimate food producers in the supply chain

(define-data-var admin principal tx-sender)

;; Map of verified suppliers
(define-map verified-suppliers
  principal
  {
    name: (string-utf8 100),
    registration-number: (string-utf8 50),
    verified: bool,
    verification-date: uint
  }
)

;; Public function to register a new supplier (only admin can call)
(define-public (register-supplier
    (supplier-principal principal)
    (name (string-utf8 100))
    (registration-number (string-utf8 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set verified-suppliers
      supplier-principal
      {
        name: name,
        registration-number: registration-number,
        verified: true,
        verification-date: block-height
      }
    ))
  )
)

;; Public function to revoke a supplier's verification
(define-public (revoke-supplier (supplier-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some (map-get? verified-suppliers supplier-principal)) (err u404))
    (let ((supplier-data (unwrap-panic (map-get? verified-suppliers supplier-principal))))
      (ok (map-set verified-suppliers
        supplier-principal
        (merge supplier-data { verified: false })
      ))
    )
  )
)

;; Read-only function to check if a supplier is verified
(define-read-only (is-verified-supplier (supplier-principal principal))
  (match (map-get? verified-suppliers supplier-principal)
    supplier-data (get verified supplier-data)
    false
  )
)

;; Read-only function to get supplier details
(define-read-only (get-supplier-details (supplier-principal principal))
  (map-get? verified-suppliers supplier-principal)
)

;; Function to transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (var-set admin new-admin))
  )
)
