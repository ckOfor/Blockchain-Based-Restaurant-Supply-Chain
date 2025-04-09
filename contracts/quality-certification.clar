;; Quality Certification Contract
;; Records food safety compliance and certifications

(define-data-var admin principal tx-sender)

;; Define contract references
(define-data-var ingredient-tracking-contract principal tx-sender)

;; Map of authorized certifiers
(define-map authorized-certifiers
  principal
  {
    name: (string-utf8 100),
    certification-authority: (string-utf8 100),
    active: bool
  }
)

;; Map of certifications for ingredient batches
(define-map batch-certifications
  uint
  {
    certifier: principal,
    certification-type: (string-utf8 50),
    certification-date: uint,
    expiration-date: uint,
    notes: (string-utf8 200)
  }
)

;; Function to set the ingredient tracking contract reference
(define-public (set-ingredient-tracking-contract (contract-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (var-set ingredient-tracking-contract contract-principal))
  )
)

;; Public function to add an authorized certifier
(define-public (add-certifier
    (certifier-principal principal)
    (name (string-utf8 100))
    (certification-authority (string-utf8 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (map-set authorized-certifiers
      certifier-principal
      {
        name: name,
        certification-authority: certification-authority,
        active: true
      }
    ))
  )
)

;; Public function to revoke a certifier's authorization
(define-public (revoke-certifier (certifier-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some (map-get? authorized-certifiers certifier-principal)) (err u404))
    (let ((certifier-data (unwrap-panic (map-get? authorized-certifiers certifier-principal))))
      (ok (map-set authorized-certifiers
        certifier-principal
        (merge certifier-data { active: false })
      ))
    )
  )
)

;; Public function to certify a batch of ingredients
(define-public (certify-batch
    (batch-id uint)
    (certification-type (string-utf8 50))
    (expiration-date uint)
    (notes (string-utf8 200)))
  (let ((certifier-data (unwrap! (map-get? authorized-certifiers tx-sender) (err u401))))
    (asserts! (get active certifier-data) (err u403))

    ;; Skip batch existence check for now to avoid contract dependency
    ;; In a production environment, you would want to implement this check

    (ok (map-set batch-certifications
      batch-id
      {
        certifier: tx-sender,
        certification-type: certification-type,
        certification-date: block-height,
        expiration-date: expiration-date,
        notes: notes
      }
    ))
  )
)

;; Read-only function to check if a certifier is authorized
(define-read-only (is-authorized-certifier (certifier-principal principal))
  (match (map-get? authorized-certifiers certifier-principal)
    certifier-data (get active certifier-data)
    false
  )
)

;; Read-only function to get certification details for a batch
(define-read-only (get-certification (batch-id uint))
  (map-get? batch-certifications batch-id)
)

;; Read-only function to check if a batch certification is valid (not expired)
(define-read-only (is-certification-valid (batch-id uint))
  (match (map-get? batch-certifications batch-id)
    certification-data (< block-height (get expiration-date certification-data))
    false
  )
)
