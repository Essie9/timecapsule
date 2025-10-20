;; Time Capsule - Decentralized Time-Locked Message & Asset Storage
;; A production-ready smart contract for storing messages, NFTs, and STX with time-lock release

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-invalid-unlock-time (err u303))
(define-constant err-still-locked (err u304))
(define-constant err-already-opened (err u305))
(define-constant err-invalid-recipient (err u306))
(define-constant err-transfer-failed (err u307))
(define-constant err-invalid-amount (err u308))
(define-constant err-capsule-limit (err u309))
(define-constant err-invalid-message (err u310))

;; Maximum capsules per user
(define-constant max-capsules-per-user u100)

;; Data Variables
(define-data-var capsule-nonce uint u0)
(define-data-var total-capsules uint u0)
(define-data-var total-value-locked uint u0)
(define-data-var total-opened uint u0)
(define-data-var contract-paused bool false)

;; Capsule Structure
(define-map capsules
    uint
    {
        creator: principal,
        recipient: principal,
        message: (string-utf8 1000),
        stx-amount: uint,
        unlock-height: uint,
        created-at: uint,
        opened-at: (optional uint),
        is-opened: bool,
        capsule-type: (string-ascii 20),
        metadata: (optional (string-utf8 500))
    }
)

;; User capsule tracking
(define-map user-capsule-count
    principal
    uint
)

;; User's capsule list (for efficient querying)
(define-map user-capsules
    { user: principal, index: uint }
    uint
)

;; Capsule access log (for security audit trail)
(define-map access-log
    uint
    {
        accessed-by: principal,
        access-time: uint,
        action: (string-ascii 20)
    }
)

;; Public capsule registry (optional public visibility)
(define-map public-capsules
    uint
    bool
)

;; Read-Only Functions

(define-read-only (get-capsule (capsule-id uint))
    (ok (map-get? capsules capsule-id))
)

(define-read-only (get-capsule-count (user principal))
    (ok (default-to u0 (map-get? user-capsule-count user)))
)

(define-read-only (get-user-capsule-id (user principal) (index uint))
    (ok (map-get? user-capsules { user: user, index: index }))
)

(define-read-only (is-capsule-unlocked (capsule-id uint))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
    )
        (ok (>= stacks-block-height (get unlock-height capsule)))
    )
)

(define-read-only (time-until-unlock (capsule-id uint))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
        (current-height stacks-block-height)
        (unlock-height (get unlock-height capsule))
    )
        (if (>= current-height unlock-height)
            (ok u0)
            (ok (- unlock-height current-height))
        )
    )
)

(define-read-only (get-contract-stats)
    (ok {
        total-capsules: (var-get total-capsules),
        total-value-locked: (var-get total-value-locked),
        total-opened: (var-get total-opened),
        is-paused: (var-get contract-paused)
    })
)

(define-read-only (can-open-capsule (capsule-id uint) (caller principal))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
    )
        (ok (and
            (is-eq caller (get recipient capsule))
            (>= stacks-block-height (get unlock-height capsule))
            (not (get is-opened capsule))
        ))
    )
)

(define-read-only (is-public-capsule (capsule-id uint))
    (ok (default-to false (map-get? public-capsules capsule-id)))
)

(define-read-only (get-access-log (capsule-id uint))
    (ok (map-get? access-log capsule-id))
)

;; Private helper functions

(define-private (add-to-user-capsules (user principal) (capsule-id uint))
    (let (
        (current-count (default-to u0 (map-get? user-capsule-count user)))
    )
        (map-set user-capsules
            { user: user, index: current-count }
            capsule-id
        )
        (map-set user-capsule-count user (+ current-count u1))
    )
)

(define-private (log-access (capsule-id uint) (action (string-ascii 20)))
    (map-set access-log capsule-id {
        accessed-by: tx-sender,
        access-time: stacks-block-height,
        action: action
    })
)

;; Public Functions

;; Create a time capsule with STX and message
(define-public (create-capsule
    (recipient principal)
    (message (string-utf8 1000))
    (stx-amount uint)
    (unlock-blocks uint)
    (capsule-type (string-ascii 20))
    (is-public bool)
    (metadata (optional (string-utf8 500))))
    (let (
        (capsule-id (+ (var-get capsule-nonce) u1))
        (unlock-height (+ stacks-block-height unlock-blocks))
        (creator-count (default-to u0 (map-get? user-capsule-count tx-sender)))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (not (is-eq recipient tx-sender)) err-invalid-recipient)
        (asserts! (> unlock-blocks u0) err-invalid-unlock-time)
        (asserts! (> (len message) u0) err-invalid-message)
        (asserts! (< creator-count max-capsules-per-user) err-capsule-limit)
        
        ;; Transfer STX to contract if amount > 0
        (if (> stx-amount u0)
            (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
            true
        )
        
        ;; Create capsule record
        (map-set capsules capsule-id {
            creator: tx-sender,
            recipient: recipient,
            message: message,
            stx-amount: stx-amount,
            unlock-height: unlock-height,
            created-at: stacks-block-height,
            opened-at: none,
            is-opened: false,
            capsule-type: capsule-type,
            metadata: metadata
        })
        
        ;; Add to creator's capsule list
        (add-to-user-capsules tx-sender capsule-id)
        
        ;; Add to recipient's capsule list
        (add-to-user-capsules recipient capsule-id)
        
        ;; Mark as public if requested
        (if is-public
            (map-set public-capsules capsule-id true)
            true
        )
        
        ;; Log creation
        (log-access capsule-id "created")
        
        ;; Update global state
        (var-set capsule-nonce capsule-id)
        (var-set total-capsules (+ (var-get total-capsules) u1))
        (var-set total-value-locked (+ (var-get total-value-locked) stx-amount))
        
        (ok capsule-id)
    )
)

;; Open and retrieve capsule contents
(define-public (open-capsule (capsule-id uint))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
        (stx-amount (get stx-amount capsule))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (is-eq tx-sender (get recipient capsule)) err-unauthorized)
        (asserts! (>= stacks-block-height (get unlock-height capsule)) err-still-locked)
        (asserts! (not (get is-opened capsule)) err-already-opened)
        
        ;; Transfer STX to recipient if amount > 0
        (if (> stx-amount u0)
            (try! (as-contract (stx-transfer? stx-amount tx-sender (get recipient capsule))))
            true
        )
        
        ;; Mark capsule as opened
        (map-set capsules capsule-id
            (merge capsule {
                is-opened: true,
                opened-at: (some stacks-block-height)
            })
        )
        
        ;; Log opening
        (log-access capsule-id "opened")
        
        ;; Update global stats
        (var-set total-opened (+ (var-get total-opened) u1))
        (var-set total-value-locked (- (var-get total-value-locked) stx-amount))
        
        (ok true)
    )
)

;; Preview capsule content (for recipient only, checks if unlocked)
(define-public (preview-capsule (capsule-id uint))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
    )
        (asserts! (is-eq tx-sender (get recipient capsule)) err-unauthorized)
        (asserts! (>= stacks-block-height (get unlock-height capsule)) err-still-locked)
        
        ;; Log preview
        (log-access capsule-id "previewed")
        
        (ok {
            message: (get message capsule),
            creator: (get creator capsule),
            stx-amount: (get stx-amount capsule),
            created-at: (get created-at capsule),
            capsule-type: (get capsule-type capsule),
            metadata: (get metadata capsule)
        })
    )
)

;; Creator can add additional STX to existing capsule
(define-public (add-funds-to-capsule (capsule-id uint) (additional-amount uint))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
        (current-amount (get stx-amount capsule))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (is-eq tx-sender (get creator capsule)) err-unauthorized)
        (asserts! (not (get is-opened capsule)) err-already-opened)
        (asserts! (> additional-amount u0) err-invalid-amount)
        
        ;; Transfer additional STX
        (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
        
        ;; Update capsule
        (map-set capsules capsule-id
            (merge capsule {
                stx-amount: (+ current-amount additional-amount)
            })
        )
        
        ;; Log addition
        (log-access capsule-id "funds-added")
        
        ;; Update total value locked
        (var-set total-value-locked (+ (var-get total-value-locked) additional-amount))
        
        (ok true)
    )
)

;; Creator can update message before unlock (emergency edit)
(define-public (update-message (capsule-id uint) (new-message (string-utf8 1000)))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (is-eq tx-sender (get creator capsule)) err-unauthorized)
        (asserts! (< stacks-block-height (get unlock-height capsule)) err-still-locked)
        (asserts! (not (get is-opened capsule)) err-already-opened)
        (asserts! (> (len new-message) u0) err-invalid-message)
        
        ;; Update message
        (map-set capsules capsule-id
            (merge capsule {
                message: new-message
            })
        )
        
        ;; Log update
        (log-access capsule-id "message-updated")
        
        (ok true)
    )
)

;; Extend unlock time (creator only, only before unlock)
(define-public (extend-unlock-time (capsule-id uint) (additional-blocks uint))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
        (current-unlock (get unlock-height capsule))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (is-eq tx-sender (get creator capsule)) err-unauthorized)
        (asserts! (< stacks-block-height current-unlock) err-still-locked)
        (asserts! (not (get is-opened capsule)) err-already-opened)
        (asserts! (> additional-blocks u0) err-invalid-unlock-time)
        
        ;; Update unlock height
        (map-set capsules capsule-id
            (merge capsule {
                unlock-height: (+ current-unlock additional-blocks)
            })
        )
        
        ;; Log extension
        (log-access capsule-id "time-extended")
        
        (ok true)
    )
)

;; Emergency withdraw (creator only, with time restrictions for security)
(define-public (emergency-withdraw (capsule-id uint))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
        (stx-amount (get stx-amount capsule))
        (created-at (get created-at capsule))
        (unlock-height (get unlock-height capsule))
    )
        (asserts! (is-eq tx-sender (get creator capsule)) err-unauthorized)
        (asserts! (not (get is-opened capsule)) err-already-opened)
        ;; Security: Only allow emergency withdraw if capsule is very far in future (> 52560 blocks ~ 1 year)
        (asserts! (> (- unlock-height stacks-block-height) u52560) err-unauthorized)
        ;; Or if capsule was just created (< 144 blocks ~ 1 day)
        (asserts! (< (- stacks-block-height created-at) u144) err-unauthorized)
        (asserts! (> stx-amount u0) err-invalid-amount)
        
        ;; Transfer STX back to creator
        (try! (as-contract (stx-transfer? stx-amount tx-sender (get creator capsule))))
        
        ;; Mark as opened to prevent reuse
        (map-set capsules capsule-id
            (merge capsule {
                is-opened: true,
                opened-at: (some stacks-block-height),
                stx-amount: u0
            })
        )
        
        ;; Log emergency withdraw
        (log-access capsule-id "emergency-withdraw")
        
        ;; Update stats
        (var-set total-value-locked (- (var-get total-value-locked) stx-amount))
        
        (ok true)
    )
)

;; Cancel unopened capsule (creator only, before unlock with penalty)
(define-public (cancel-capsule (capsule-id uint))
    (let (
        (capsule (unwrap! (map-get? capsules capsule-id) err-not-found))
        (stx-amount (get stx-amount capsule))
        (penalty (/ stx-amount u10))
        (refund-amount (- stx-amount penalty))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (is-eq tx-sender (get creator capsule)) err-unauthorized)
        (asserts! (not (get is-opened capsule)) err-already-opened)
        (asserts! (< stacks-block-height (get unlock-height capsule)) err-still-locked)
        
        ;; Transfer refund (90%) to creator, penalty (10%) stays in contract
        (if (> refund-amount u0)
            (try! (as-contract (stx-transfer? refund-amount tx-sender (get creator capsule))))
            true
        )
        
        ;; Mark as cancelled
        (map-set capsules capsule-id
            (merge capsule {
                is-opened: true,
                opened-at: (some stacks-block-height)
            })
        )
        
        ;; Log cancellation
        (log-access capsule-id "cancelled")
        
        ;; Update stats
        (var-set total-value-locked (- (var-get total-value-locked) refund-amount))
        
        (ok true)
    )
)

;; Create a group capsule (multiple recipients can view)
(define-public (create-group-capsule
    (recipients (list 10 principal))
    (message (string-utf8 1000))
    (stx-per-recipient uint)
    (unlock-blocks uint)
    (metadata (optional (string-utf8 500))))
    (let (
        (total-stx (* stx-per-recipient (len recipients)))
        (start-id (var-get capsule-nonce))
    )
        (asserts! (not (var-get contract-paused)) err-unauthorized)
        (asserts! (> unlock-blocks u0) err-invalid-unlock-time)
        (asserts! (> (len message) u0) err-invalid-message)
        (asserts! (> (len recipients) u0) err-invalid-recipient)
        
        ;; Transfer total STX if amount > 0
        (if (> total-stx u0)
            (try! (stx-transfer? total-stx tx-sender (as-contract tx-sender)))
            true
        )
        
        ;; Create individual capsules for each recipient using fold
        (fold create-capsule-for-recipient 
            recipients 
            { message: message, stx: stx-per-recipient, blocks: unlock-blocks, meta: metadata, count: u0 })
        
        (ok start-id)
    )
)

(define-private (create-capsule-for-recipient 
    (recipient principal)
    (context { message: (string-utf8 1000), stx: uint, blocks: uint, meta: (optional (string-utf8 500)), count: uint }))
    (let (
        (capsule-id (+ (var-get capsule-nonce) u1))
        (unlock-height (+ stacks-block-height (get blocks context)))
    )
        (map-set capsules capsule-id {
            creator: tx-sender,
            recipient: recipient,
            message: (get message context),
            stx-amount: (get stx context),
            unlock-height: unlock-height,
            created-at: stacks-block-height,
            opened-at: none,
            is-opened: false,
            capsule-type: "group",
            metadata: (get meta context)
        })
        
        (add-to-user-capsules tx-sender capsule-id)
        (add-to-user-capsules recipient capsule-id)
        
        (var-set capsule-nonce capsule-id)
        (var-set total-capsules (+ (var-get total-capsules) u1))
        (var-set total-value-locked (+ (var-get total-value-locked) (get stx context)))
        
        (merge context { count: (+ (get count context) u1) })
    )
)

(define-private (create-individual-capsule-for-group-helper
    (recipient principal)
    (message (string-utf8 1000))
    (stx-amount uint)
    (unlock-blocks uint)
    (metadata (optional (string-utf8 500))))
    (let (
        (capsule-id (+ (var-get capsule-nonce) u1))
        (unlock-height (+ stacks-block-height unlock-blocks))
    )
        (map-set capsules capsule-id {
            creator: tx-sender,
            recipient: recipient,
            message: message,
            stx-amount: stx-amount,
            unlock-height: unlock-height,
            created-at: stacks-block-height,
            opened-at: none,
            is-opened: false,
            capsule-type: "group",
            metadata: metadata
        })
        
        (add-to-user-capsules tx-sender capsule-id)
        (add-to-user-capsules recipient capsule-id)
        
        (var-set capsule-nonce capsule-id)
        (var-set total-capsules (+ (var-get total-capsules) u1))
        (var-set total-value-locked (+ (var-get total-value-locked) stx-amount))
        
        capsule-id
    )
)

;; Admin Functions

(define-public (toggle-contract-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused (not (var-get contract-paused)))
        (ok (var-get contract-paused))
    )
)

(define-public (withdraw-penalties (amount uint))
    (let (
        (contract-balance (stx-get-balance (as-contract tx-sender)))
        (locked-value (var-get total-value-locked))
        (available (- contract-balance locked-value))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= amount available) err-invalid-amount)
        (asserts! (> amount u0) err-invalid-amount)
        
        (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
        (ok true)
    )
)