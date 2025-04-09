;; Inventory Management Contract
;; Tracks stock levels and usage in restaurants

(define-data-var admin principal tx-sender)

;; Define contract references
(define-data-var ingredient-tracking-contract principal tx-sender)

;; Map of registered restaurants
(define-map restaurants
  principal
  {
    name: (string-utf8 100),
    location: (string-utf8 200),
    active: bool
  }
)

;; Map of restaurant inventory items
(define-map inventory
  { restaurant: principal, item-id: uint }
  {
    batch-id: uint,
    product-name: (string-utf8 100),
    quantity-remaining: uint,
    received-date: uint,
    last-updated: uint
  }
)

;; Map to track the next item ID for each restaurant
(define-map next-item-id
  principal
  uint
)

;; Function to set the ingredient tracking contract reference
(define-public (set-ingredient-tracking-contract (contract-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (ok (var-set ingredient-tracking-contract contract-principal))
  )
)

;; Public function to register a restaurant
(define-public (register-restaurant
    (restaurant-principal principal)
    (name (string-utf8 100))
    (location (string-utf8 200)))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (map-set restaurants
      restaurant-principal
      {
        name: name,
        location: location,
        active: true
      }
    )
    (map-set next-item-id restaurant-principal u1)
    (ok true)
  )
)

;; Public function to deactivate a restaurant
(define-public (deactivate-restaurant (restaurant-principal principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u403))
    (asserts! (is-some (map-get? restaurants restaurant-principal)) (err u404))
    (let ((restaurant-data (unwrap-panic (map-get? restaurants restaurant-principal))))
      (ok (map-set restaurants
        restaurant-principal
        (merge restaurant-data { active: false })
      ))
    )
  )
)

;; Public function for a restaurant to receive inventory from a batch
(define-public (receive-inventory (batch-id uint) (quantity uint) (product-name (string-utf8 100)))
  (let ((restaurant-data (unwrap! (map-get? restaurants tx-sender) (err u401)))
        (item-id (default-to u1 (map-get? next-item-id tx-sender))))

    (asserts! (get active restaurant-data) (err u403))

    ;; Add to inventory - using provided product name instead of fetching from batch
    (map-set inventory
      { restaurant: tx-sender, item-id: item-id }
      {
        batch-id: batch-id,
        product-name: product-name,
        quantity-remaining: quantity,
        received-date: block-height,
        last-updated: block-height
      }
    )

    ;; Update the next item ID
    (map-set next-item-id tx-sender (+ item-id u1))

    (ok item-id)
  )
)

;; Public function to update inventory usage
(define-public (use-inventory (item-id uint) (quantity-used uint))
  (let ((inventory-key { restaurant: tx-sender, item-id: item-id })
        (item-data (unwrap! (map-get? inventory inventory-key) (err u404))))

    (asserts! (<= quantity-used (get quantity-remaining item-data)) (err u400))

    (map-set inventory
      inventory-key
      (merge item-data {
        quantity-remaining: (- (get quantity-remaining item-data) quantity-used),
        last-updated: block-height
      })
    )

    (ok true)
  )
)

;; Read-only function to get restaurant details
(define-read-only (get-restaurant (restaurant-principal principal))
  (map-get? restaurants restaurant-principal)
)

;; Read-only function to get inventory item details
(define-read-only (get-inventory-item (restaurant-principal principal) (item-id uint))
  (map-get? inventory { restaurant: restaurant-principal, item-id: item-id })
)

;; Read-only function to get the next item ID for a restaurant
(define-read-only (get-next-item-id (restaurant-principal principal))
  (default-to u1 (map-get? next-item-id restaurant-principal))
)
